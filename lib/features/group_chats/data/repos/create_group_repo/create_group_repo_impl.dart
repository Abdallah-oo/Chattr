import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_crud_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_storage.dart';
import 'package:messenger_clone0/features/group_chats/data/models/group_members_model.dart';
import 'package:messenger_clone0/features/group_chats/data/models/group_model.dart';
import 'package:messenger_clone0/features/group_chats/data/repos/create_group_repo/create_group_repo.dart';

class CreateGroupRepoImpl implements CreateGroupRepo {
  const CreateGroupRepoImpl({
    required SupabaseCrudServices crud,
    required SupabaseStorage storage,
  }) : _crud = crud,
       _storage = storage;

  final SupabaseCrudServices _crud;
  final SupabaseStorage _storage;

  @override
  Future<Either<SupabaseError, String>> uploadGroupImage(File imageFile) async {
    try {
      final path = await _storage.uploadImage(file: imageFile,storageFile: 'group_image');
      final url = _storage.getFileUrl(path: path,storageFile: 'group_image');
      return right(url);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, String>> createGroup({
    required String groupName,
    required String imageUrl,
    required String createdBy,
  }) async {
    try {
      final groupData = GroupModel(
        createdBy: createdBy,
        name: groupName,
        createdAt: DateTime.now().toUtc(),
        image: imageUrl,
        lastMessage: null,
        lastMessageTime: null,
      );

      final response = await _crud.post(
        table: 'groups',
        data: groupData.toJson(),
      );

      return right(response['group_id'] as String);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, Unit>> addGroupMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      final member = GroupMemberModel(groupId: groupId, userId: userId);
      await _crud.postWithoutSelect(
        table: 'group_members',
        data: member.toJson(),
      );
      return right(unit);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }
}
