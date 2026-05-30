import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_members_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/data/repos/edit_group_data_repo/edit_group_data_repo.dart';
import 'package:dartz/dartz.dart';

class EditGroupDataRepoImpl implements EditGroupDataRepo {
  final SupabaseCrudServices _crud;
  final SupabaseStorage _storage;
  EditGroupDataRepoImpl({
    required SupabaseCrudServices crud,
    required SupabaseStorage storage,
  }) : _crud = crud,
       _storage = storage;

  @override
  Future<Either<SupabaseError, Unit>> editGrroupDataRepo({
    required GroupModel groupData,
    required String? name,
    required List<UserModel> members,
    required File? newImageFile,
  }) async {
    try {
      Map<String, dynamic> data = {};

      if (name != null && name.trim().isNotEmpty) {
        data['name'] = name;
      }

      if (newImageFile != null) {
        final String newImagePath = await _storage.updateImage(
          newFile: newImageFile,
          oldPath: groupData.image!,
          storageFile: 'group_image',
        );
        final String imagePath = _storage.getFileUrl(
          path: newImagePath,
          storageFile: 'group_image',
        );
        data['image'] = imagePath;
      }
      if (members.isNotEmpty) {
        for (var m in members) {
          final GroupMemberModel member = GroupMemberModel(
            groupId: groupData.id!,
            userId: m.id!,
          );
          await _crud.postWithoutSelect(
            table: 'group_members',
            data: member.toJson(),
          );
        }
      }

      await _crud.put(
        table: "groups",
        data: data,
        column: "group_id",
        id: groupData.id,
      );
      return const Right(unit);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }
  }
}
