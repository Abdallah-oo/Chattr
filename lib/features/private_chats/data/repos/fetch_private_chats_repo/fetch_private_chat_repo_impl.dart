import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_chats_repo/fetch_private_chat_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FetchPrivateChatRepoImpl implements FetchPrivateChatRepo {
  final AuthService _auth;
  final SupabaseClientManager client;

  FetchPrivateChatRepoImpl(this._auth, this.client);
  SupabaseClient get _client => client.client;

  @override
  Future<Either<SupabaseError, Map<String, UserModel>>> fetchFriendsData(
    List<String> friendIds,
  ) async {
    try {
      if (friendIds.isEmpty) return const Right({});

      final response = await _client
          .from('messenger_users')
          .select()
          .inFilter('id', friendIds);

      return right({for (final u in response) u['id']: UserModel.fromJson(u)});
    } catch (e) {
      return Left(SupabaseError(message: "$e"));
    }
  }

  @override
  Future<Either<String, List<PrivateChatModel>>> getLocalChats() async {
    try {
      final chats = await HiveService.getPrivateChats();
      return Right(chats);
    } catch (e) {
      return Left('$e');
    }
  }

  @override
  Future<Either<String, Unit>> saveChatsLocally(
    List<PrivateChatModel> chats,
  ) async {
    try {
      await HiveService.clearChats();
      for (final chat in chats) {
        await HiveService.savePrivateChat(chat);
      }
      return const Right(unit);
    } catch (e) {
      return Left('$e');
    }
  }

  @override
  Future<Either<SupabaseError, List<PrivateChatModel>>>
  fetchChatsFromServer() async {
    try {
      final myId = _auth.currentUser!.id;

      final response = await _client
          .from('private_chats')
          .select()
          .contains('members', [myId])
          .order('last_message_time', ascending: false);

      if (response.isEmpty) {
        await HiveService.clearChats();
        return right([]);
      }

      final friendIds = <String>{};
      for (final chat in response) {
        final members = List<String>.from(chat['members']);
        final friendId = members.firstWhere(
          (id) => id != myId,
          orElse: () => '',
        );
        if (friendId.isNotEmpty) friendIds.add(friendId);
      }

      // ✅ استخرج الـ usersMap قبل الـ map وتحقق من الـ error
      final usersMapResult = await fetchFriendsData(friendIds.toList());

      if (usersMapResult.isLeft()) {
        return Left(
          SupabaseError(
            message: usersMapResult.fold((l) => l.message, (_) => ''),
          ),
        );
      }

      final usersMap = usersMapResult.fold(
        (_) => <String, UserModel>{},
        (r) => r,
      );

      final chats = response.map<PrivateChatModel>((chat) {
        final members = List<String>.from(chat['members']);
        final friendId = members.firstWhere(
          (id) => id != myId,
          orElse: () => '',
        );
        // ✅ friend جوا الـ map مباشرة — مش late خارجها
        final friend = usersMap[friendId]!;
        return PrivateChatModel.fromJson(chat, friend);
      }).toList();

      await saveChatsLocally(chats);
      return Right(chats);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }
  }
}
