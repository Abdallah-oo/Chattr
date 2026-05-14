import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';

abstract interface class AddFriendRepo {
  Future<Either<SupabaseError,PrivateChatModel>> addFriend(String email);
}


