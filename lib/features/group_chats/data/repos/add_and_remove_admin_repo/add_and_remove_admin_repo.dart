import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';

abstract interface class AddAndRemoveAdminRepo {
  Future<Either<SupabaseError, Unit>> addAdminAndRemove({
    required String groupId,
    required String userId,
    required bool isAdmin,
  });
}
