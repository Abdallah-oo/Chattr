import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthRepo {
  //login
  Future<Either<SupabaseError, User>> login({
    required String email,
    required String password,
  });
  //sign up
  Future<Either<SupabaseError, User?>> signup({

    required String email,
    required String password,

  });
//verify Signup Otp
    Future<Either<SupabaseError, void>> verifySignupOtp({
    required String email,
    required String otp,
      required String name,
    required File image,
  });


  Future<Either<SupabaseError, void>> resendSignupOtp({required String email});

  //forget password 

 Future<Either<SupabaseError, void>> sendPasswordResetOtp({required String email});

  Future<Either<SupabaseError, void>> verifyPasswordResetOtp({
    required String email,
    required String otp,
  });

  Future<Either<SupabaseError, void>> updatePassword({required String newPassword});
   Future<Either<SupabaseError, Unit>> updateFCM();
 
}
