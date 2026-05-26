
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/core/cache/users_cache.dart';
import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_auth_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/group_chats/data/models/group_message_model.dart';
import 'package:messenger_clone0/features/group_chats/data/repos/fetch_group_messages_repo/fetch_group_messages_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'fetch_group_messages_state.dart';

class FetchGroupMessagesCubit extends Cubit<FetchGroupMessagesState> {
  FetchGroupMessagesCubit({
    required FetchGroupMessagesRepo repo,
    required SupabaseClientManager client,
    required AuthService auth,
  }) : _repo = repo,
       _auth = auth,
       _clientManager = client,
       super(FetchGroupMessagesInitial());

  final FetchGroupMessagesRepo _repo;
  final AuthService _auth;
  final SupabaseClientManager _clientManager;
  SupabaseClient get _client => _clientManager.client;

  final Map<String, List<GroupMessageModel>> _cache = {};
  final Map<String, DateTime?> _oldestDate = {};
  final Map<String, bool> _hasMoreMap = {};
  final Map<String, bool> _loadingMoreMap = {};
  final Map<String, StreamSubscription> _streams = {};
  final Set<String> _pendingTempIds = {};

  static const int _pageSize = 30;

  bool hasMore(String groupId) => _hasMoreMap[groupId] ?? true;
  List<GroupMessageModel>? getMessages(String groupId) => _cache[groupId];

  // ─────────────────────────────────────────────────────────────────
  // LOAD INITIAL
  // ─────────────────────────────────────────────────────────────────

  Future<void> loadInitialMessages({required String groupId}) async {
    final alreadyCached = _cache[groupId]?.isNotEmpty == true;
    final alreadySubscribed = _streams.containsKey(groupId);

    if (alreadyCached && alreadySubscribed) {
      _emit(groupId);
      return;
    }

    if (!alreadyCached) emit(FetchGroupMessagesLoading());

    // 1️⃣ Hive
    if (!alreadyCached) {
      final localResult = await _repo.getLocalMessages(
        groupId: groupId,
        limit: _pageSize,
      );
      localResult.fold((l) => debugPrint('❌ getLocalMessages (group): $l'), (
        local,
      ) {
        if (local.isNotEmpty) {
          _cache[groupId] = List.from(local);
          _emit(groupId);
        }
      });
    }

    // 2️⃣ Server — خارج الـ fold عشان الـ async يشتغل صح
    if (!alreadyCached) {
      final serverResult = await _repo.fetchInitialMessages(
        groupId: groupId,
        pageSize: _pageSize,
      );

      if (serverResult.isLeft()) {
        final err = serverResult.fold((l) => l.message, (_) => '');
        debugPrint('❌ fetchInitialMessages (group): $err');
        if (_cache[groupId]?.isNotEmpty != true) {
          emit(FetchGroupMessagesFailure(errorMessage: err));
        }
      } else {
        final serverMsgs = serverResult.fold(
          (_) => <GroupMessageModel>[],
          (r) => r,
        );

        await _cacheMissingUsers(serverMsgs);
        final enriched = await _attachLocalPaths(serverMsgs);
        _cache[groupId] = _mergeWithCache(_cache[groupId], enriched);

        if (serverMsgs.isNotEmpty) {
          _oldestDate[groupId] = serverMsgs.first.createdAt;
          _hasMoreMap[groupId] = serverMsgs.length == _pageSize;
        } else {
          _hasMoreMap[groupId] = false;
        }

        await _persistAll(enriched);
        _emit(groupId);
      }
    }

    // 3️⃣ Realtime
    if (!alreadySubscribed) _subscribe(groupId);
  }

  // ─────────────────────────────────────────────────────────────────
  // REALTIME — sync بالكامل، مفيش async في الـ snapshot
  // ─────────────────────────────────────────────────────────────────

  void _subscribe(String groupId) {
    _cache.putIfAbsent(groupId, () => []);
    _streams[groupId]?.cancel();

    _streams[groupId] = _client
        .from('group_messages')
        .stream(primaryKey: ['message_id'])
        .eq('group_id', groupId)
        .listen((event) {
          if (isClosed) return;
          final incoming = event
              .map<GroupMessageModel>((r) => GroupMessageModel.fromJson(r))
              .toList();
          _processSnapshot(groupId, incoming);
        }, onError: (e) => debugPrint('❌ Group stream error ($groupId): $e'));
  }

  // ✅ sync بالكامل — fire and forget للـ Hive
  void _processSnapshot(String groupId, List<GroupMessageModel> incoming) {
    final list = _cache[groupId]!;
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
        final finalMsg = old.messageId == null
            ? enriched.copyWith(createdAt: old.createdAt)
            : enriched;

        if (_equal(old, finalMsg)) continue;

        list[idx] = finalMsg;
        // ✅ fire and forget
        _repo
            .saveMessageLocally(finalMsg)
            .then((r) => r.fold((l) => debugPrint('save failed: $l'), (_) {}));
      } else {
        list.add(enriched);
        _repo
            .saveMessageLocally(enriched)
            .then((r) => r.fold((l) => debugPrint('save failed: $l'), (_) {}));
      }

      dirty = true;
    }

    if (dirty) _sortAndEmit(groupId);
  }

  // ─────────────────────────────────────────────────────────────────
  // PAGINATION
  // ─────────────────────────────────────────────────────────────────

  Future<void> loadMoreMessages(String groupId) async {
    if (_hasMoreMap[groupId] != true) return;
    if (_loadingMoreMap[groupId] == true) return;
    if (_oldestDate[groupId] == null) return;

    _loadingMoreMap[groupId] = true;

    try {
      final result = await _repo.fetchMoreMessages(
        groupId: groupId,
        before: _oldestDate[groupId]!,
        pageSize: _pageSize,
      );

      if (result.isLeft()) {
        debugPrint(
          'loadMoreMessages (group) failed: ${result.fold((l) => l.message, (_) => '')}',
        );
        return;
      }

      final msgs = result.fold((_) => <GroupMessageModel>[], (r) => r);

      if (msgs.isEmpty) {
        _hasMoreMap[groupId] = false;
      } else {
        // ✅ async خارج الـ fold
        await _cacheMissingUsers(msgs);

        final reversed = msgs.reversed.toList();
        final existingIds = _cache[groupId]!.map((m) => m.messageId).toSet();
        final fresh = reversed
            .where((m) => !existingIds.contains(m.messageId))
            .toList();

        _cache[groupId]!.insertAll(0, fresh);
        _oldestDate[groupId] = reversed.first.createdAt;
        _hasMoreMap[groupId] = msgs.length == _pageSize;

        await _persistAll(fresh);
      }

      _sortAndEmit(groupId);
    } finally {
      // ✅ دايماً بيتنفذ
      _loadingMoreMap[groupId] = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // MARK AS READ
  // ─────────────────────────────────────────────────────────────────

  Future<void> markGroupAsRead({required String groupId}) async {
    final result = await _repo.markGroupAsRead(
      groupId: groupId,
      userId: _auth.currentUser!.id,
    );
    result.fold((l) => debugPrint('❌ markGroupAsRead: $l'), (_) {});
  }

  // ─────────────────────────────────────────────────────────────────
  // LOCAL OPS
  // ─────────────────────────────────────────────────────────────────

  void addLocalMessage({
    required String groupId,
    required GroupMessageModel message,
  }) {
    _cache.putIfAbsent(groupId, () => []);
    _cache[groupId]!.add(message);
    _pendingTempIds.add(message.tempId);
    _emit(groupId);
  }

  Future<void> replaceTempMessage({
    required String groupId,
    required String tempId,
    required GroupMessageModel serverMessage,
  }) async {
    _pendingTempIds.remove(tempId);

    final list = _cache[groupId];
    if (list == null) return;

    final idx = list.indexWhere((m) => m.tempId == tempId);

    if (idx == -1) {
      final streamIdx = list.indexWhere(
        (m) => m.messageId == serverMessage.messageId,
      );
      if (streamIdx != -1) {
        final old = list[streamIdx];
        list[streamIdx] = old.copyWith(
          localPath: serverMessage.localPath ?? old.localPath,
          status: GroupMessageStatus.sent,
        );
        _repo
            .saveMessageLocally(list[streamIdx])
            .then((r) => r.fold((l) => debugPrint('save failed: $l'), (_) {}));
        _emit(groupId);
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
      await _repo.saveMessageLocally(updated);
    }

    _emit(groupId);
  }

  void markMessageFailed({required String groupId, required String tempId}) {
    _pendingTempIds.remove(tempId);

    final list = _cache[groupId];
    if (list == null) return;

    final idx = list.indexWhere((m) => m.tempId == tempId);
    if (idx == -1) return;

    list[idx] = list[idx].copyWith(status: GroupMessageStatus.failed);
    _emit(groupId);
  }

  // ─────────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────────

  Future<void> deleteGroupMessages({
    required String groupId,
    required List<GroupMessageModel> messages,
  }) async {
    final list = _cache[groupId];
    if (list == null) return;

    for (final msg in messages) {
      final idx = list.indexWhere((m) => m.messageId == msg.messageId);
      if (idx == -1) continue;

      list[idx] = list[idx].copyWith(status: GroupMessageStatus.deleting);
      _emit(groupId);

      final result = await _repo.deleteMessages([msg.messageId!]);
      result.fold(
        (l) {
          list[idx] = list[idx].copyWith(
            status: GroupMessageStatus.deleteFailed,
          );
        },
        (_) {
          list[idx] = list[idx].copyWith(
            isDeleted: true,
            status: GroupMessageStatus.sent,
          );
        },
      );

      _repo
          .saveMessageLocally(list[idx])
          .then((r) => r.fold((l) => debugPrint('save failed: $l'), (_) {}));
    }

    _emit(groupId);
  }

  // ─────────────────────────────────────────────────────────────────
  // EDIT
  // ─────────────────────────────────────────────────────────────────

  Future<void> editMessageGroup({
    required String groupId,
    required GroupMessageModel message,
    required String content,
  }) async {
    final list = _cache[groupId];
    if (list == null) return;

    final idx = list.indexWhere((m) => m.messageId == message.messageId);
    if (idx == -1) return;

    list[idx] = list[idx].copyWith(status: GroupMessageStatus.editing);
    _emit(groupId);

    final result = await _repo.editMessage(
      messageId: message.messageId!,
      content: content,
    );

    result.fold(
      (l) {
        list[idx] = list[idx].copyWith(status: GroupMessageStatus.editingFaild);
      },
      (_) {
        list[idx] = list[idx].copyWith(
          content: content,
          status: GroupMessageStatus.sent,
        );
      },
    );

    _repo
        .saveMessageLocally(list[idx])
        .then((r) => r.fold((l) => debugPrint('save failed: $l'), (_) {}));
    _emit(groupId);
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────

  int _findIndex(List<GroupMessageModel> list, GroupMessageModel msg) {
    return list.indexWhere(
      (m) =>
          (msg.messageId != null && m.messageId == msg.messageId) ||
          (msg.tempId.isNotEmpty && m.tempId == msg.tempId),
    );
  }

  bool _equal(GroupMessageModel a, GroupMessageModel b) {
    return a.messageId == b.messageId &&
        a.content == b.content &&
        a.status == b.status &&
        a.isDeleted == b.isDeleted &&
        a.localPath == b.localPath;
  }

  List<GroupMessageModel> _mergeWithCache(
    List<GroupMessageModel>? existing,
    List<GroupMessageModel> incoming,
  ) {
    if (existing == null) return incoming;
    return incoming.map((msg) {
      final cached = existing.firstWhere(
        (m) =>
            (m.messageId != null && m.messageId == msg.messageId) ||
            m.tempId == msg.tempId,
        orElse: () => msg,
      );
      return cached.localPath != null
          ? msg.copyWith(localPath: cached.localPath)
          : msg;
    }).toList();
  }

  Future<List<GroupMessageModel>> _attachLocalPaths(
    List<GroupMessageModel> msgs,
  ) async {
    return Future.wait(
      msgs.map((msg) async {
        final isMedia =
            msg.messageType == GroupMessageType.image ||
            msg.messageType == GroupMessageType.voice;
        if (!isMedia || msg.messageId == null) return msg;
        final saved = await _repo.getLocalMessage(msg.messageId!);
        return saved.fold(
          (l) {
            debugPrint('getLocalMessage failed: $l');
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

  Future<void> _cacheMissingUsers(List<GroupMessageModel> msgs) async {
    final missing = msgs
        .map((m) => m.senderId)
        .where((id) => !UsersCache.contains(id))
        .toSet()
        .toList();

    if (missing.isEmpty) return;

    final result = await _repo.fetchMissingUsers(missing);
    result.fold((l) => debugPrint('fetchMissingUsers failed: $l'), (rows) {
      for (final r in rows) {
        final user = UserModel.fromJson(r);
        UsersCache.addUser(user);
        HiveService.saveUser(user);
      }
    });
  }

  // ✅ async صح — بيتانتظر في loadInitialMessages و loadMoreMessages
  Future<void> _persistAll(List<GroupMessageModel> msgs) async {
    for (final m in msgs) {
      final result = await _repo.saveMessageLocally(m);
      result.fold((l) => debugPrint('save failed: $l'), (_) {});
    }
  }

  void _sortAndEmit(String groupId) {
    _cache[groupId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _emit(groupId);
  }

  // ✅ groupId في الـ state — بيمنع مشكلة الـ UI بتاع group تاني
  void _emit(String groupId) {
    if (isClosed) return;
    emit(
      FetchGroupMessagesSuccess(
        groupId: groupId,
        messages: List.unmodifiable(_cache[groupId] ?? []),
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
