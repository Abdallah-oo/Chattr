import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class FetchContactsRepo {
  Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchAllContacts(
    List<String> ids,
  );
  Future<Either<SupabaseError, UserModel>> fetchMe(String myId);
  Either<SupabaseError, RealtimeChannel> subscribeToUser(String userId);
  Future<Either<String, List<UserModel>>> getUsers();
  Future<Either<String, Unit>> saveUsers(List<UserModel> users);
  Future<Either<String, Unit>> saveUser(UserModel user);
}
