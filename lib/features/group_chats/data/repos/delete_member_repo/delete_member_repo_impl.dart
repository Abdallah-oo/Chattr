import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/group_chats/data/repos/delete_member_repo/delete_member_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeleteMemberRepoImpl implements DeleteMemberRepo {
  final SupabaseClientManager _clientManager;
  DeleteMemberRepoImpl(this._clientManager);
  SupabaseClient get _client => _clientManager.client;
  @override
  Future<Either<SupabaseError, Unit>> deleteMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);

      await Future.delayed(const Duration(seconds: 1));
      return const Right(unit);
    } catch (e) {
      return Left(SupabaseError(message: "$e"));
    }
  }
}
