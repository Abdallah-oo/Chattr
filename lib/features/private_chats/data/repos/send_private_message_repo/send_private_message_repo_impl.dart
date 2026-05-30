import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo.dart';
import 'package:dartz/dartz.dart';

class SendPrivateMessageRepoImpl implements SendPrivateMessageRepo {
  const SendPrivateMessageRepoImpl({
    required SupabaseCrudServices crud,
    required SupabaseStorage storage,
  }) : _crud = crud,
       _storage = storage;

  final SupabaseCrudServices _crud;
  final SupabaseStorage _storage;

  @override
  Future<Either<SupabaseError, PrivateMessageModel>> sendMessage(
    PrivateMessageModel message,
  ) async {
    try {
      final response = await _crud.post(
        table: 'message',
        data: message.toJson(),
      );
      return right(PrivateMessageModel.fromJson(response));
    } catch (e) {
      return left(SupabaseError(message: e.toString()));
    }
  }

  @override
  Future<Either<SupabaseError, String>> uploadImage(File imageFile) async {
    try {
      final path = await _storage.uploadImage(
        file: imageFile,
        storageFile: 'chat_images',
      );
      final url = _storage.getFileUrl(path: path, storageFile: 'chat_images');
      return right(url);
    } catch (e) {
      return left(SupabaseError(message: e.toString()));
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
      return left(SupabaseError(message: e.toString()));
    }
  }
}
