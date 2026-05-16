import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_crud_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';
import 'package:messenger_clone0/features/private_chats/data/repos/add_friend_repo/add_friend_repo.dart';

class AddFriendRepoImpl implements AddFriendRepo {
  final SupabaseCrudServices _crud;
  final SupabaseClientManager _client;
  AddFriendRepoImpl(this._crud, this._client);

  @override
  Future<Either<SupabaseError, PrivateChatModel>> addFriend(
    String email,
  ) async {
    try {
      final myId = _client.client.auth.currentUser?.id;

      // 1. Verify friend exists
      final friendData = await _crud.getByFilter(
        table: 'messenger_users',
        filterColumn: 'email',
        filterValue: email,
      );

      if (friendData == null) {
        return Left(SupabaseError(message: 'User not found'));
      }

      final friendId = friendData['id'] as String;

      // 2. Prevent adding yourself
      if (friendId == myId) {
        return Left(SupabaseError(message: 'You cannot add yourself'));
      }

      // 3. Check if chat already exists
      final existing = await _crud.getByFilter(
        table: 'private_chats',
        filterColumn: 'members_id',
        filterValue: '$myId-$friendId',
      );

      if (existing != null) {
        return Left(SupabaseError(message: 'Chat already exists'));
      }
      final chatData = PrivateChatModel(
        members: [myId!, friendId],
        membersId: '$myId-$friendId',
        lastMessage: null,
        lastMessageTime: null,
        createdAt: DateTime.now().toUtc(),
      );

      // 4. Create chat
      final response = await _crud.post(
        table: 'private_chats',
        data: chatData.toJson(),
      );

      final friend = UserModel.fromJson(friendData);
      await HiveService.saveUser(friend);

      final chat = PrivateChatModel.fromJson(response, friend);
      return Right(chat);
    } catch (e) {
      return Left(SupabaseError(message: "$e"));
    }
  }
}
