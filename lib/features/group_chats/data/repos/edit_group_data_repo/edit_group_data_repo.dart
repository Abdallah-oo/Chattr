import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/group_chats/data/models/group_model.dart';

abstract interface class EditGroupDataRepo {
  Future<Either<SupabaseError, Unit>> editGrroupDataRepo({
    required GroupModel groupData,
    required String? name,
    required List<UserModel> members,
    required File? newImageFile,
  });
}
