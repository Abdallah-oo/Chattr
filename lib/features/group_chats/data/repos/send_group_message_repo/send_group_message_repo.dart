import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/group_chats/data/models/group_message_model.dart';

abstract interface class SendGroupMessageRepo {
  Future<Either<SupabaseError, GroupMessageModel>> sendMessage(
    GroupMessageModel message,
  );

  Future<Either<SupabaseError, String>> uploadImage(File imageFile);

  Future<Either<SupabaseError, String>> uploadAudio(File audioFile);
}
