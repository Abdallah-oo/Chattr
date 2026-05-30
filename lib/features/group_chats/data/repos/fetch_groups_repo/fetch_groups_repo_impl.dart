import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_groups_repo/fetch_groups_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FetchGroupsRepoImpl implements FetchGroupsRepo {
  const FetchGroupsRepoImpl(this._clientManager);

  final SupabaseClientManager _clientManager;
  SupabaseClient get _client => _clientManager.client;

  @override
  Future<Either<SupabaseError, List<String>>> fetchMyGroupIds(
    String userId,
  ) async {
    try {
      final rows = await _client
          .from('group_members')
          .select('group_id')
          .eq('user_id', userId);

      final ids = rows.map<String>((e) => e['group_id'] as String).toList();
      return right(ids);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchGroupMembers(
    List<String> groupIds,
  ) async {
    try {
      final rows = await _client
          .from('group_members')
          .select('group_id, is_admin, user:messenger_users(*)')
          .inFilter('group_id', groupIds);

      return right(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchGroupsData(
    List<String> groupIds,
  ) async {
    try {
      final rows = await _client
          .from('groups')
          .select('*')
          .inFilter('group_id', groupIds);

      return right(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, Map<String, int>>> fetchUnreadCounts(
    String userId,
  ) async {
    try {
      final rows = await _client.rpc(
        'get_groups_unread_count',
        params: {'p_user_id': userId},
      );

      final map = <String, int>{
        for (final e in rows) e['group_id'] as String: e['unread_count'] as int,
      };

      return right(map);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, List<GroupModel>>> getLocalGroups() async {
    try {
      final groups = await HiveService.getGroups();
      return right(groups);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, Unit>> saveGroupsLocally(
    List<GroupModel> groups,
  ) async {
    try {
      await HiveService.replaceGroups(groups);
      return right(unit);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }
}
