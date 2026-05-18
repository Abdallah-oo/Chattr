import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';

abstract interface class FetchPrivateChatRepo {
  Future<Either<SupabaseError, List<PrivateChatModel>>> fetchChatsFromServer();

  Future<Either<String, List<PrivateChatModel>>> getLocalChats();

  Future<Either<String, Unit>> saveChatsLocally(List<PrivateChatModel> chats);

  Future<Either<SupabaseError, Map<String, UserModel>>> fetchFriendsData(
    List<String> friendIds,
  );
}
