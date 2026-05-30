import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class AddToContactsRepo {
  Future<Either<SupabaseError, UserModel>> addToContacts(String contactEmail);
}
