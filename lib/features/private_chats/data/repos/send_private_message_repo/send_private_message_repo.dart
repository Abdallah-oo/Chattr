import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class SendPrivateMessageRepo {
  Future<Either<SupabaseError, PrivateMessageModel>> sendMessage(
    PrivateMessageModel message,
  );

  Future<Either<SupabaseError, String>> uploadImage(File imageFile);

  Future<Either<SupabaseError, String>> uploadAudio(File audioFile);
}
