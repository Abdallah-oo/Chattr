import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:dartz/dartz.dart';

abstract interface class DeleteMemberRepo {
  Future<Either<SupabaseError, Unit>> deleteMember({
    required String groupId,
    required String userId,
  });
}
