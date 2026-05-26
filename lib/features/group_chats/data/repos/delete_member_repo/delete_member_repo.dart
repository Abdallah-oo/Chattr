import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';

abstract interface class DeleteMemberRepo {
  Future<Either<SupabaseError, Unit>> deleteMember({
    required String groupId,
    required String userId,
  });
}
