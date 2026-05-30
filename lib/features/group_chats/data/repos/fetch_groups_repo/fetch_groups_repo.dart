import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class FetchGroupsRepo {
  Future<Either<SupabaseError, List<String>>> fetchMyGroupIds(String userId);

  Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchGroupMembers(
    List<String> groupIds,
  );

  Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchGroupsData(
    List<String> groupIds,
  );

  Future<Either<SupabaseError, Map<String, int>>> fetchUnreadCounts(
    String userId,
  );

  // ─── Hive ───────────────────────────────────────────────────────
  Future<Either<SupabaseError, List<GroupModel>>> getLocalGroups();

  Future<Either<SupabaseError, Unit>> saveGroupsLocally(
    List<GroupModel> groups,
  );
}
