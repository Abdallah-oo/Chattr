import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
abstract interface class AddToContactsRepo{
Future<Either<SupabaseError, UserModel>> addToContacts(String contactEmail);

}