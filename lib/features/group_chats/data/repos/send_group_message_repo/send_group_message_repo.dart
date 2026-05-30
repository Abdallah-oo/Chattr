import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class SendGroupMessageRepo {
  Future<Either<SupabaseError, GroupMessageModel>> sendMessage(
    GroupMessageModel message,
  );

  Future<Either<SupabaseError, String>> uploadImage(File imageFile);

  Future<Either<SupabaseError, String>> uploadAudio(File audioFile);
}
