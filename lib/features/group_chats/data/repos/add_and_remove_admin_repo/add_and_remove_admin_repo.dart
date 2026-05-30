import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:dartz/dartz.dart';

abstract interface class AddAndRemoveAdminRepo {
  Future<Either<SupabaseError, Unit>> addAdminAndRemove({
    required String groupId,
    required String userId,
    required bool isAdmin,
  });
}
