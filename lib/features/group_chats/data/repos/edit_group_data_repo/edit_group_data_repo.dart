import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class EditGroupDataRepo {
  Future<Either<SupabaseError, Unit>> editGrroupDataRepo({
    required GroupModel groupData,
    required String? name,
    required List<UserModel> members,
    required File? newImageFile,
  });
}
