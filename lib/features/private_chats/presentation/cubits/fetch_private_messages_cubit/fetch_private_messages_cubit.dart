import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/core/cache/users_cache.dart';
import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_auth_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_message_model.dart';
import 'package:messenger_clone0/features/private_chats/data/repos/fetch_private_messages_repo/fetch_private_messages_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
part 'fetch_private_messages_state.dart';

class FetchPrivateMessagesCubit extends Cubit<FetchPrivateMessagesState> {
  FetchPrivateMessagesCubit({
    required FetchPrivateMessagesRepo repo,
    required this.client,
    required AuthService auth,
  }) : _repo = repo,
       _auth = auth,
       super(FetchPrivateMessagesInitial());

  final FetchPrivateMessagesRepo _repo;
  final SupabaseClientManager client;
  final AuthService _auth;
  SupabaseClient get _client => client.client;
  String get _myId => _auth.currentUser!.id;

  final Map<String, List<PrivateMessageModel>> _cache = {};
  final Map<String, DateTime?> _oldestDate = {};
  final Map<String, bool> _hasMoreMap = {};
  final Map<String, bool> _loadingMoreMap = {};
  final Map<String, StreamSubscription> _streams = {};

  // tempIds اللي لسه upload — الـ stream يتجاهلهم تماماً
  final Set<String> _pendingTempIds = {};

  // reference للـ FetchPrivateChatsCubit عشان نحدّث الـ unread count
  dynamic _chatsCubit;
  void setChatsCubit(dynamic cubit) => _chatsCubit = cubit;

  static const int _pageSize = 30;

  bool hasMore(String chatId) => _hasMoreMap[chatId] ?? true;
  List<PrivateMessageModel>? getMessages(String chatId) => _cache[chatId];

  /// عدد الرسايل الغير مقروءة اللي مش أنا اللي بعتها
  int getUnreadCount(String chatId) {
    final msgs = _cache[chatId];
    if (msgs == null) return 0;
    return msgs.where((m) => m.read == false && m.senderId != _myId).length;
  }

  // ─────────────────────────────────────────────────────────────────
  // LOAD INITIAL
  // ─────────────────────────────────────────────────────────────────

  Future<void> loadInitialMessages({required String chatId}) async {
    final alreadyCached = _cache[chatId]?.isNotEmpty == true;
    final alreadySubscribed = _streams.containsKey(chatId);

    if (alreadyCached && alreadySubscribed) {
      _emit(chatId);
      return;
    }

    if (!alreadyCached) emit(FetchPrivateMessagesLoading());

    // 1️⃣ Hive — لو مفيش cache
    if (!alreadyCached) {
      final local = await _repo.getLocalMessages(
        chatId: chatId,
        limit: _pageSize,
      );
      local.fold(
        (l) {
          debugPrint('❌ loadInitialMessages: $l');
          if (_cache[chatId]?.isNotEmpty == true) {
            _emit(chatId);
          } else {
            emit(FetchPrivateMessagesfailure(errMessage: l.toString()));
          }
        },
        (local) {
          if (local.isNotEmpty) {
            _cache[chatId] = List.from(local);
            _emit(chatId);
          }
        },
      );
    }

    // 2️⃣ Server — بس لو أول مرة
    if (!alreadyCached) {
      final serverMsgs = await _repo.fetchInitialMessages(
        chatId: chatId,
        pageSize: _pageSize,
      );
      serverMsgs.fold(
        (l) {
          debugPrint('❌ loadInitialMessages: $l');
          if (_cache[chatId]?.isNotEmpty == true) {
            _emit(chatId);
          } else {
            emit(FetchPrivateMessagesfailure(errMessage: l.toString()));
          }
        },
        (serverMsgs) async {
          await _fetchMissingUsers(serverMsgs);
          final enriched = await _attachLocalPaths(serverMsgs);
          final existing = _cache[chatId];
          final merged = _mergeWithCache(existing, enriched);
          _cache[chatId] = merged;

          if (serverMsgs.isNotEmpty) {
            _oldestDate[chatId] = serverMsgs.first.createdAt;
            _hasMoreMap[chatId] = serverMsgs.length == _pageSize;
          } else {
            _hasMoreMap[chatId] = false;
          }

          _persistAll(enriched);
          _emit(chatId);
        },
      );
    }

    // 3️⃣ Realtime — بس لو مش مشترك
    if (!alreadySubscribed) _subscribe(chatId);
  }

  // ─────────────────────────────────────────────────────────────────
  // REALTIME
  // ─────────────────────────────────────────────────────────────────

  void _subscribe(String chatId) {
    _cache.putIfAbsent(chatId, () => []);
    _streams[chatId]?.cancel();

    _streams[chatId] = _client
        .from('message')
        .stream(primaryKey: ['message_id'])
        .eq('chat_id', chatId)
        .listen((event) {
          if (isClosed) return;
          final incoming = event
              .map<PrivateMessageModel>((r) => PrivateMessageModel.fromJson(r))
              .toList();
          _processSnapshot(chatId, incoming);
        }, onError: (e) => debugPrint('❌ Realtime stream error ($chatId): $e'));
  }

  void _processSnapshot(
    String chatId,
    List<PrivateMessageModel> incoming,
  ) async {
    final list = _cache[chatId]!;
    bool dirty = false;

    for (final msg in incoming) {
      if (_pendingTempIds.contains(msg.tempId)) continue;

      final idx = _findIndex(list, msg);
      final existingPath = idx != -1 ? list[idx].localPath : null;
      final enriched = existingPath != null
          ? msg.copyWith(localPath: existingPath)
          : msg;

      if (idx != -1) {
        final old = list[idx];

        var finalMsg = old.messageId == null
            ? enriched.copyWith(createdAt: old.createdAt)
            : enriched;

        final isMine = finalMsg.senderId == _myId;
        if (!isMine && old.read == true && finalMsg.read != true) {
          finalMsg = finalMsg.copyWith(read: true);
        }
        if (_equal(old, finalMsg)) continue;

        list[idx] = finalMsg;
        final result = await _repo.saveMessageLocally(finalMsg);
        result.fold((l) => debugPrint('save message failed: $l'), (r) => r);
      } else {
        list.add(enriched);
        final result = await _repo.saveMessageLocally(enriched);
        result.fold((l) => debugPrint('save message failed: $l'), (r) => r);
      }

      dirty = true;
    }

    if (dirty) _sortAndEmit(chatId);
  }

  // ─────────────────────────────────────────────────────────────────
  // PAGINATION
  // ─────────────────────────────────────────────────────────────────

  Future<void> loadMoreMessages(String chatId) async {
    if (_hasMoreMap[chatId] != true) return;
    if (_loadingMoreMap[chatId] == true) return;
    if (_oldestDate[chatId] == null) return;

    _loadingMoreMap[chatId] = true;

    final msgs = await _repo.fetchMoreMessages(
      chatId: chatId,
      before: _oldestDate[chatId]!,
      pageSize: _pageSize,
    );

    msgs.fold(
      (l) {
        debugPrint(' load More Messages failed: $l');
      },
      (msgs) async {
        if (msgs.isEmpty) {
          _hasMoreMap[chatId] = false;
        } else {
          await _fetchMissingUsers(msgs);

          final reversed = msgs.reversed.toList();
          final existingIds = _cache[chatId]!.map((m) => m.messageId).toSet();
          final fresh = reversed
              .where((m) => !existingIds.contains(m.messageId))
              .toList();

          _cache[chatId]!.insertAll(0, fresh);
          _oldestDate[chatId] = reversed.first.createdAt;
          _hasMoreMap[chatId] = msgs.length == _pageSize;

          _persistAll(fresh);
        }

        _sortAndEmit(chatId);
      },
    );
    _loadingMoreMap[chatId] = false;
  }

  // ─────────────────────────────────────────────────────────────────
  // OPTIMISTIC LOCAL OPS
  // ─────────────────────────────────────────────────────────────────

  void addLocalMessage({
    required String chatId,
    required PrivateMessageModel message,
  }) {
    _cache.putIfAbsent(chatId, () => []);
    _cache[chatId]!.add(message);
    _pendingTempIds.add(message.tempId);
    _emit(chatId);
  }

  Future<void> replaceTempMessage({
    required String chatId,
    required String tempId,
    required PrivateMessageModel serverMessage,
  }) async {
    _pendingTempIds.remove(tempId);

    final list = _cache[chatId];
    if (list == null) return;

    final idx = list.indexWhere((m) => m.tempId == tempId);

    if (idx == -1) {
      // الـ stream سبق وحط الرسالة — عدّل بس الـ status والـ localPath
      final streamIdx = list.indexWhere(
        (m) => m.messageId == serverMessage.messageId,
      );
      if (streamIdx != -1) {
        final old = list[streamIdx];
        list[streamIdx] = old.copyWith(
          localPath: serverMessage.localPath ?? old.localPath,
          privateMessageStatus: PrivateMessageStatus.sent,
        );
        final result = await _repo.saveMessageLocally(list[streamIdx]);
        result.fold((l) => debugPrint('save message failed: $l'), (r) => r);
        _emit(chatId);
      }
      return;
    }

    final temp = list[idx];
    final updated = serverMessage.copyWith(
      createdAt: temp.createdAt,
      localPath: serverMessage.localPath ?? temp.localPath,
    );

    list[idx] = updated;

    await _repo.deleteMessageLocally(tempId);
    if (serverMessage.messageId != null) {
      final result = await _repo.saveMessageLocally(updated);
      result.fold((l) {
        debugPrint('save message failed: $l');
      }, (r) => r);
    }

    _emit(chatId);
  }

  void markMessageFailed({required String chatId, required String tempId}) {
    _pendingTempIds.remove(tempId);

    final list = _cache[chatId];
    if (list == null) return;

    final idx = list.indexWhere((m) => m.tempId == tempId);
    if (idx == -1) return;

    list[idx] = list[idx].copyWith(
      privateMessageStatus: PrivateMessageStatus.failed,
    );
    _emit(chatId);
  }

  // ─────────────────────────────────────────────────────────────────
  // MARK AS READ
  // ─────────────────────────────────────────────────────────────────

  Future<void> markAllAsRead({required String chatId}) async {
    final list = _cache[chatId];
    if (list == null) return;

    final unread = list
        .where(
          (m) => m.read == false && m.senderId != _myId && m.messageId != null,
        )
        .toList();

    if (unread.isEmpty) return;

    // 1. Cache + Hive فوراً (optimistic)
    for (var i = 0; i < list.length; i++) {
      if (list[i].read == false && list[i].senderId != _myId) {
        list[i] = list[i].copyWith(read: true);
        final result = await _repo.saveMessageLocally(list[i]);
        result.fold((l) => debugPrint('save message failed: $l'), (r) => r);
      }
    }
    _emit(chatId);

    // 2. حدّث الـ unread count قبل الـ DB
    _chatsCubit?.refreshUnreadCount(chatId);

    try {
      final ids = unread.map((m) => m.messageId!).toList();
      debugPrint('🔵 updating ${ids.length} messages to read=true: $ids');
      await _repo.markMessagesAsRead(ids);
      debugPrint('🟢 DB update done');
    } catch (e) {
      debugPrint('❌ DB error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────────

  Future<void> deletePrivateMessages({
    required String chatId,
    required List<PrivateMessageModel> messages,
  }) async {
    final list = _cache[chatId];
    if (list == null) return;

    for (final msg in messages) {
      final idx = list.indexWhere((m) => m.messageId == msg.messageId);
      if (idx == -1) continue;

      list[idx] = list[idx].copyWith(
        privateMessageStatus: PrivateMessageStatus.deleting,
      );
      _emit(chatId);

      final result = await _repo.deleteMessages([msg.messageId!]);
      result.fold(
        (l) {
          list[idx] = list[idx].copyWith(
            privateMessageStatus: PrivateMessageStatus.deleteFailed,
          );
        },
        (r) {
          list[idx] = list[idx].copyWith(
            isDeleted: true,
            privateMessageStatus: PrivateMessageStatus.sent,
          );
        },
      );

      _repo.saveMessageLocally(list[idx]);
    }

    _emit(chatId);
  }

  // ─────────────────────────────────────────────────────────────────
  // EDIT
  // ─────────────────────────────────────────────────────────────────

  Future<void> editPrivateMessage({
    required String chatId,
    required PrivateMessageModel message,
    required String content,
  }) async {
    final list = _cache[chatId];
    if (list == null) return;

    final idx = list.indexWhere((m) => m.messageId == message.messageId);
    if (idx == -1) return;

    list[idx] = list[idx].copyWith(
      privateMessageStatus: PrivateMessageStatus.editing,
    );
    _emit(chatId);

    final result = await _repo.editMessage(
      messageId: message.messageId!,
      content: content,
    );

    result.fold(
      (l) {
        list[idx] = list[idx].copyWith(
          privateMessageStatus: PrivateMessageStatus.editingFaild,
        );
      },
      (r) {
        list[idx] = list[idx].copyWith(
          content: content,
          privateMessageStatus: PrivateMessageStatus.sent,
        );
      },
    );

    _repo.saveMessageLocally(list[idx]);
    _emit(chatId);
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────

  int _findIndex(List<PrivateMessageModel> list, PrivateMessageModel msg) {
    return list.indexWhere(
      (m) =>
          (msg.messageId != null && m.messageId == msg.messageId) ||
          (msg.tempId.isNotEmpty && m.tempId == msg.tempId),
    );
  }

  bool _equal(PrivateMessageModel a, PrivateMessageModel b) {
    return a.messageId == b.messageId &&
        a.content == b.content &&
        a.privateMessageStatus == b.privateMessageStatus &&
        a.isDeleted == b.isDeleted &&
        a.read == b.read &&
        a.localPath == b.localPath;
  }

  Future<void> _fetchMissingUsers(List<PrivateMessageModel> msgs) async {
    final missing = msgs
        .map((m) => m.senderId)
        .where((id) => !UsersCache.contains(id))
        .toSet();

    if (missing.isEmpty) return;

    final rows = await _client
        .from('messenger_users')
        .select()
        .inFilter('id', missing.toList());

    for (final r in rows) {
      final user = UserModel.fromJson(r);
      UsersCache.addUser(user);
      await HiveService.saveUser(user);
    }
  }

  List<PrivateMessageModel> _mergeWithCache(
    List<PrivateMessageModel>? existing,
    List<PrivateMessageModel> incoming,
  ) {
    if (existing == null) return incoming;
    return incoming.map((msg) {
      final cached = existing.firstWhere(
        (m) =>
            (m.messageId != null && m.messageId == msg.messageId) ||
            m.tempId == msg.tempId,
        orElse: () => msg,
      );
      if (cached.read == true && msg.read != true) {
        return msg.copyWith(read: true);
      }
      return msg;
    }).toList();
  }

  Future<List<PrivateMessageModel>> _attachLocalPaths(
    List<PrivateMessageModel> msgs,
  ) async {
    return Future.wait(
      msgs.map((msg) async {
        final isMedia =
            msg.privateMessageType == PrivateMessageType.image ||
            msg.privateMessageType == PrivateMessageType.voice;
        if (!isMedia || msg.messageId == null) return msg;
        final saved = await _repo.getLocalMessage(msg.messageId!);
        return saved.fold(
          (l) {
            debugPrint('get local message failed:$l');
            return msg;
          },
          (saved) {
            if (saved?.localPath == null) return msg;
            return msg.copyWith(localPath: saved!.localPath);
          },
        );
      }),
    );
  }

  void _persistAll(List<PrivateMessageModel> msgs) async {
    for (final m in msgs) {
      final result = await _repo.saveMessageLocally(m);

      result.fold((l) => debugPrint('save message failed: $l'), (r) => r);
    }
  }

  void _sortAndEmit(String chatId) {
    _cache[chatId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _emit(chatId);
  }

  void _emit(String chatId) {
    if (isClosed) return;
    emit(
      FetchPrivateMessagesSuccess(
        messages: List.unmodifiable(_cache[chatId] ?? []),
      ),
    );
  }

  @override
  Future<void> close() {
    for (final s in _streams.values) {
      s.cancel();
    }
    return super.close();
  }
}
