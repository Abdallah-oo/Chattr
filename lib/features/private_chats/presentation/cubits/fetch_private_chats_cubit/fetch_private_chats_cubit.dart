import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';
import 'package:messenger_clone0/features/private_chats/data/repos/fetch_private_chats_repo/fetch_private_chat_repo.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'fetch_private_chats_state.dart';

class FetchPrivateChatsCubit extends Cubit<FetchPrivateChatsState> {
  FetchPrivateChatsCubit({
    required this.fetchMessages,
    required FetchPrivateChatRepo repo,
    required this.client,
  }) : _repo = repo,
       super(FetchPrivateChatsInitial());

  final FetchPrivateMessagesCubit fetchMessages;
  final FetchPrivateChatRepo _repo;
  final SupabaseClientManager client;
  SupabaseClient get _client => client.client;

  RealtimeChannel? _privateChatsChannel;
  RealtimeChannel? _presenceChannel;
  Timer? _debounceTimer;

  List<PrivateChatModel> privateChatsCache = [];

  // ─────────────────────────────────────────────────────────────────
  // FETCH CHATS
  // ─────────────────────────────────────────────────────────────────

  Future<void> fetchPrivateChats() async {
      if (privateChatsCache.isNotEmpty) {
      emit(FetchPrivateChatsSuccess(chats: List.from(privateChatsCache)));
      // خليه يحدّث في الخلفية من غير loading
      await _fetchFromServer();
      return;
    }
    try {
      emit(FetchPrivateChatsloading());

      // 1️⃣ Hive أولاً
      final localResult = await _repo.getLocalChats();

      if (localResult.isLeft()) {
        emit(
          FetchChatsFailure(
            errorMessage: localResult.fold((l) => l, (_) => ''),
          ),
        );
        return;
      } else {
        final r = localResult.fold((_) => <PrivateChatModel>[], (r) => r);
        if (r.isNotEmpty) {
          privateChatsCache = r;
          await _loadMessagesAndUpdateUnread(privateChatsCache);
          if (!isClosed) {
            emit(FetchPrivateChatsSuccess(chats: List.from(privateChatsCache)));
          }
        }
      }

      // 2️⃣ Server
      await _fetchFromServer();

      // 3️⃣ Realtime
      _listenToChatsChanges();
      _listenToFriendsPresence();
    } on AuthException catch (e) {
      emit(FetchChatsFailure(errorMessage: e.message));
    } on SocketException {
      emit(FetchChatsFailure(errorMessage: 'No internet connection'));
    } catch (e) {
      emit(FetchChatsFailure(errorMessage: '$e'));
    }
  }
  // ─────────────────────────────────────────────────────────────────
  // FETCH FROM SERVER
  // ─────────────────────────────────────────────────────────────────

  Future<void> _fetchFromServer() async {
    final result = await _repo.fetchChatsFromServer();

    if (result.isLeft()) {
      final err = result.fold((l) => l.message, (_) => '');
      emit(FetchChatsFailure(errorMessage: err));
      return;
    }

    final r = result.fold((_) => <PrivateChatModel>[], (r) => r);

    if (r.isEmpty) {
      privateChatsCache = [];
      if (!isClosed) emit(FetchPrivateChatsSuccess(chats: []));
      return;
    }

    privateChatsCache = r;
    await _loadMessagesAndUpdateUnread(privateChatsCache);
    _listenToFriendsPresence();

    if (!isClosed) {
      emit(FetchPrivateChatsSuccess(chats: List.from(privateChatsCache)));
    }
  }
  // ─────────────────────────────────────────────────────────────────
  // CORE — حمّل رسايل كل chat واحسب الـ unread count
  // ─────────────────────────────────────────────────────────────────

  Future<void> _loadMessagesAndUpdateUnread(
    List<PrivateChatModel> chats,
  ) async {
    await Future.wait(
      chats.map((chat) async {
        if (chat.chatId == null) return;
        await fetchMessages.loadInitialMessages(chatId: chat.chatId!);
      }),
    );

    for (var i = 0; i < privateChatsCache.length; i++) {
      final chatId = privateChatsCache[i].chatId;
      if (chatId == null) continue;
      final unread = fetchMessages.getUnreadCount(chatId);
      debugPrint('🟡 _loadMessagesAndUpdateUnread: $chatId → $unread');
      privateChatsCache[i] = privateChatsCache[i].copyWith(unreadCount: unread);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // UNREAD
  // ─────────────────────────────────────────────────────────────────

  void refreshUnreadCount(String chatId) {
    final idx = privateChatsCache.indexWhere((c) => c.chatId == chatId);
    if (idx == -1) return;
    final unread = fetchMessages.getUnreadCount(chatId);
    debugPrint('🔵 refreshUnreadCount: $chatId → $unread');
    privateChatsCache[idx] = privateChatsCache[idx].copyWith(
      unreadCount: unread,
    );

    if (!isClosed) {
      emit(FetchPrivateChatsSuccess(chats: List.from(privateChatsCache)));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // FRIENDS PRESENCE — stream واحد لكل الـ friends
  // ─────────────────────────────────────────────────────────────────

  void _listenToFriendsPresence() {
    _presenceChannel?.unsubscribe();

    final friendIds = privateChatsCache
        .map((c) => c.friend?.id)
        .whereType<String>()
        .toList();

    if (friendIds.isEmpty) return;

    _presenceChannel = _client
        .channel('friends_presence')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messenger_users',
          callback: (payload) {
            final updatedId = payload.newRecord['id'] as String?;
            if (updatedId == null) return;
            if (!friendIds.contains(updatedId)) return;

            final idx = privateChatsCache.indexWhere(
              (c) => c.friend?.id == updatedId,
            );
            if (idx == -1) return;

            final updatedFriend = privateChatsCache[idx].friend?.copyWith(
              isOnLine: payload.newRecord['is_online'] as bool?,
              lastSeen: payload.newRecord['last_seen'] != null
                  ? DateTime.tryParse(payload.newRecord['last_seen'] as String)
                  : null,
            );

            if (updatedFriend == null) return;

            privateChatsCache[idx] = privateChatsCache[idx].copyWith(
              friend: updatedFriend,
            );

            if (!isClosed) {
              emit(
                FetchPrivateChatsSuccess(chats: List.from(privateChatsCache)),
              );
            }
          },
        )
        .subscribe();
  }
 
  // ─────────────────────────────────────────────────────────────────
  // CHATS REALTIME
  // ─────────────────────────────────────────────────────────────────

  void _listenToChatsChanges() {
    _privateChatsChannel?.unsubscribe();

    _privateChatsChannel = _client
        .channel('private_chats_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'private_chats',
          callback: (payload) {
            final chatId =
                payload.newRecord['chat_id'] ?? payload.oldRecord['chat_id'];
            debugPrint('📡 Realtime chats: $chatId');
            _debouncedFetch();
          },
        )
        .subscribe();
  }

  void _debouncedFetch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _fetchFromServer);
  }



  // ─────────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _privateChatsChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    return super.close();
  }
}
