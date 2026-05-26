import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/group_chats/data/repos/add_and_remove_admin_repo/add_and_remove_admin_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddAndRemoveAdminRepoImpl implements AddAndRemoveAdminRepo {
  final SupabaseClientManager _clientManager;

  AddAndRemoveAdminRepoImpl(this._clientManager);
  SupabaseClient get _client => _clientManager.client;

  @override
  Future<Either<SupabaseError, Unit>> addAdminAndRemove({
    required String groupId,
    required String userId,
    required bool isAdmin,
  }) async {
    try {
      await _client
          .from('group_members')
          .update({'is_admin': !isAdmin})
          .eq('group_id', groupId)
          .eq('user_id', userId);
      await Future.delayed(const Duration(milliseconds: 1500));
      return right(unit);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }
}
