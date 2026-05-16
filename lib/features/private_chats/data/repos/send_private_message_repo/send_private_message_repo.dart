import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_message_model.dart';

abstract interface class SendPrivateMessageRepo {
  Future<Either<SupabaseError, PrivateMessageModel>> sendMessage(
    PrivateMessageModel message,
  );

  Future<Either<SupabaseError, String>> uploadImage(File imageFile);

  Future<Either<SupabaseError, String>> uploadAudio(File audioFile);
}
