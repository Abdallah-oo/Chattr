import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/contacts/data/repos/fetch_contacts_repo/fetch_contacts_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FetchContactsRepoImpl implements FetchContactsRepo {
  final SupabaseClient _client;
  FetchContactsRepoImpl(this._client);

 @override
  Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchAllContacts(
    List<String> ids,
  ) async {
    try {
      final result = await _client
          .from('messenger_users')
          .select()
          .inFilter('id', ids);

      return right(result);
    } catch (e) {
      return left(SupabaseError(message: "$e"));
    }
  }

  @override
  Either<SupabaseError, RealtimeChannel> subscribeToUser(String userId) {
    try {
      final channel = _client.channel('my-contacts-$userId');
      return right(channel);
    } catch (e) {
      return left(SupabaseError(message: e.toString()));
    }
  }

  @override
  Future<Either<String, List<UserModel>>> getUsers() async {
    try {
      final allUsers = await HiveService.getUsers();
      return right(allUsers);
    } catch (e) {
      return left('$e');
    }
  }

  @override
  Future<Either<String, Unit>> saveUser(UserModel user) async {
    try {
      await HiveService.saveUser(user);
      return right(unit);
    } catch (e) {
      return left('$e');
    }
  }

  @override
  Future<Either<String, Unit>> saveUsers(List<UserModel> users) async {
    try {
      await HiveService.replaceUsers(users);
      return right(unit);
    } catch (e) {
      return left('$e');
    }
  }
}
