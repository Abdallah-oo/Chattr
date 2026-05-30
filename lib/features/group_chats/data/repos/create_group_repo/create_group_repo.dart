import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:dartz/dartz.dart';

abstract interface class CreateGroupRepo {
  Future<Either<SupabaseError, String>> uploadGroupImage(File imageFile);

  Future<Either<SupabaseError, String>> createGroup({
    required String groupName,
    required String imageUrl,
    required String createdBy,
  });

  Future<Either<SupabaseError, Unit>> addGroupMember({
    required String groupId,
    required String userId,
  });
}
