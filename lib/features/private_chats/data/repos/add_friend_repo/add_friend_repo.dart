import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class AddFriendRepo {
  Future<Either<SupabaseError, PrivateChatModel>> addFriend(String email);
}
