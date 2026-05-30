import 'dart:async';
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_groups_repo/fetch_groups_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'fetch_groups_state.dart';

class FetchGroupsCubit extends Cubit<FetchGroupsState> {
  FetchGroupsCubit({
    required FetchGroupsRepo repo,
    required SupabaseClientManager client,
    required AuthService auth,
  }) : _repo = repo,
       _auth = auth,
       _clientManager = client,
       super(FetchGroupsInitial());

  final FetchGroupsRepo _repo;
  final AuthService _auth;
  final SupabaseClientManager _clientManager;

  RealtimeChannel? _membersChannel;
  RealtimeChannel? _groupsChannel;
  RealtimeChannel? _messagesChannel;
  Timer? _debounceTimer;

  List<GroupModel> groupsCache = [];
  List<String> _groupIds = [];

  // ─────────────────────────────────────────────────────────────────
  // FETCH GROUPS — أول مرة فقط بتعمل loading
  // ─────────────────────────────────────────────────────────────────

  // ✅ بيمنع إعادة الـ fetch لو الـ cache موجود — نفس fix الـ private chats
  Future<void> fetchGroupsIfNeeded() async {
    if (groupsCache.isNotEmpty) {
      emit(FetchGroupsSuccess(groups: List.from(groupsCache)));
      return;
    }
    await fetchGroups();
  }

  Future<void> fetchGroups() async {
    try {
      emit(FetchGroupsLoading());

      // 1️⃣ Hive أولاً
      final localResult = await _repo.getLocalGroups();
      localResult.fold((l) => debugPrint('❌ getLocalGroups: $l'), (local) {
        if (local.isNotEmpty) {
          groupsCache = local;
          emit(FetchGroupsSuccess(groups: List.from(groupsCache)));
        }
      });

      // 2️⃣ Server
      await _fetchMembership();

      // 3️⃣ Realtime
      _listenToMembersChanges();
      _listenToGroupsChanges();
      _listenToMessagesChanges();
    } on AuthException catch (e) {
      emit(FetchGroupsFailure(errorMessage: e.message));
    } on SocketException {
      emit(FetchGroupsFailure(errorMessage: 'No internet connection'));
    } catch (e) {
      emit(FetchGroupsFailure(errorMessage: 'Unexpected error: $e'));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // FETCH MEMBERSHIP — silent refresh بدون loading
  // ─────────────────────────────────────────────────────────────────

  Future<void> _fetchMembership() async {
    final myId = _auth.currentUser!.id;

    // 1️⃣ جيب الـ group IDs
    final idsResult = await _repo.fetchMyGroupIds(myId);
    if (idsResult.isLeft()) {
      final err = idsResult.fold((l) => l.message, (_) => '');
      debugPrint('❌ fetchMyGroupIds: $err');
      if (groupsCache.isNotEmpty && !isClosed) {
        emit(FetchGroupsSuccess(groups: List.from(groupsCache)));
      } else if (!isClosed) {
        emit(FetchGroupsFailure(errorMessage: err));
      }
      return;
    }

    final newGroupIds = idsResult.fold((_) => <String>[], (r) => r);
    final groupsChanged = !_listEquals(_groupIds, newGroupIds);
    _groupIds = newGroupIds;

    if (_groupIds.isEmpty) {
      groupsCache = [];
      await _repo.saveGroupsLocally([]);
      if (!isClosed) emit(FetchGroupsSuccess(groups: []));
      return;
    }

    // 2️⃣ جيب الـ members
    final membersResult = await _repo.fetchGroupMembers(_groupIds);
    if (membersResult.isLeft()) {
      debugPrint(
        '❌ fetchGroupMembers: ${membersResult.fold((l) => l.message, (_) => '')}',
      );
      return;
    }
    final allMembers = membersResult.fold(
      (_) => <Map<String, dynamic>>[],
      (r) => r,
    );

    // 3️⃣ جيب بيانات الـ groups
    final groupsResult = await _repo.fetchGroupsData(_groupIds);
    if (groupsResult.isLeft()) {
      debugPrint(
        '❌ fetchGroupsData: ${groupsResult.fold((l) => l.message, (_) => '')}',
      );
      return;
    }
    final groupsResponse = groupsResult.fold(
      (_) => <Map<String, dynamic>>[],
      (r) => r,
    );

    // 4️⃣ Unread count
    final unreadResult = await _repo.fetchUnreadCounts(myId);
    final unreadMap = unreadResult.fold((_) => <String, int>{}, (r) => r);

    // 5️⃣ بناء الـ models
    final grouped = <String, Map<String, dynamic>>{};
    for (final member in allMembers) {
      final groupId = member['group_id'] as String;
      final userJson = member['user'] as Map<String, dynamic>;
      final isAdmin = member['is_admin'] ?? false;

      grouped.putIfAbsent(
        groupId,
        () => {'group_id': groupId, 'members': <Map<String, dynamic>>[]},
      );
      grouped[groupId]!['members'].add({'user': userJson, 'is_admin': isAdmin});
    }

    for (final group in groupsResponse) {
      final groupId = group['group_id'] as String;
      grouped[groupId]?.addAll(group);
    }

    groupsCache = grouped.values.map((data) {
      final groupId = data['group_id'] as String;
      return GroupModel.fromJson(
        data,
      ).copyWith(unreadCount: unreadMap[groupId] ?? 0);
    }).toList();

    // 6️⃣ Sort
    groupsCache.sort((a, b) {
      final aTime = a.lastMessageTime ?? DateTime(1970);
      final bTime = b.lastMessageTime ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    // 7️⃣ Save Hive في الخلفية
    _repo.saveGroupsLocally(groupsCache);

    // 8️⃣ أعد الـ listeners لو الـ groups اتغيرت
    if (groupsChanged) {
      _listenToGroupsChanges();
      _listenToMessagesChanges();
    }

    if (!isClosed) {
      emit(FetchGroupsSuccess(groups: List.from(groupsCache)));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // REALTIME LISTENERS
  // ─────────────────────────────────────────────────────────────────

  void _listenToMembersChanges() {
    _membersChannel?.unsubscribe();

    _membersChannel = _clientManager.client
        .channel('members_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_members',
          callback: (payload) {
            final newUserId = payload.newRecord['user_id'];
            final oldUserId = payload.oldRecord['user_id'];
            final groupId =
                payload.newRecord['group_id'] ?? payload.oldRecord['group_id'];

            final isCurrentUserAffected =
                newUserId == _auth.currentUser!.id ||
                oldUserId == _auth.currentUser!.id;

            if (isCurrentUserAffected || _groupIds.contains(groupId)) {
              _debouncedFetch();
            }
          },
        )
        .subscribe();
  }

  void _listenToGroupsChanges() {
    _groupsChannel?.unsubscribe();
    if (_groupIds.isEmpty) return;

    _groupsChannel = _clientManager.client
        .channel('groups_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'groups',
          callback: (payload) {
            final groupId =
                payload.newRecord['group_id'] ?? payload.oldRecord['group_id'];
            if (groupId != null && _groupIds.contains(groupId)) {
              _debouncedFetch();
            }
          },
        )
        .subscribe();
  }

  void _listenToMessagesChanges() {
    _messagesChannel?.unsubscribe();
    if (_groupIds.isEmpty) return;

    _messagesChannel = _clientManager.client
        .channel('messages_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_messages',
          callback: (payload) {
            final groupId = payload.newRecord['group_id'];
            if (groupId != null && _groupIds.contains(groupId)) {
              _debouncedFetch();
            }
          },
        )
        .subscribe();
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final aSet = a.toSet();
    final bSet = b.toSet();
    return aSet.difference(bSet).isEmpty && bSet.difference(aSet).isEmpty;
  }

  void _debouncedFetch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _fetchMembership);
  }

  // ─────────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _membersChannel?.unsubscribe();
    _groupsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    return super.close();
  }
}
