



import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
abstract interface class AuthRepo {
  Future<Either<SupabaseError, User>> login({
    required String email,
    required String password,
  });

  Future<Either<SupabaseError, User>> signup({
    required String name,
    required String email,
    required String password,
    required File image,
  });
}
