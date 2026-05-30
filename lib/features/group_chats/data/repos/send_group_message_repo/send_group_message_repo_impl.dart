import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/data/repos/send_group_message_repo/send_group_message_repo.dart';
import 'package:dartz/dartz.dart';

class SendGroupMessageRepoImpl implements SendGroupMessageRepo {
  const SendGroupMessageRepoImpl({
    required SupabaseCrudServices crud,
    required SupabaseStorage storage,
  }) : _crud = crud,
       _storage = storage;

  final SupabaseCrudServices _crud;
  final SupabaseStorage _storage;

  @override
  Future<Either<SupabaseError, GroupMessageModel>> sendMessage(
    GroupMessageModel message,
  ) async {
    try {
      final response = await _crud.post(
        table: 'group_messages',
        data: message.toJson(),
      );

      return right(GroupMessageModel.fromJson(response));
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, String>> uploadImage(File imageFile) async {
    try {
      final path = await _storage.uploadImage(
        file: imageFile,
        storageFile: 'group_image',
      );
      final url = _storage.getFileUrl(path: path, storageFile: 'group_image');
      return right(url);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, String>> uploadAudio(File audioFile) async {
    try {
      final path = await _storage.uploadAudio(
        file: audioFile,
        storageFile: 'chat-audio',
      );
      final url = _storage.getFileUrl(path: path, storageFile: 'chat-audio');
      return right(url);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }
}
