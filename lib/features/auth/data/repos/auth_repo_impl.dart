import 'dart:io';

import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepoImpl implements AuthRepo {
  final AuthService _authService;
  final SupabaseCrudServices _crud;
  final SupabaseStorage _storage;

  AuthRepoImpl(this._authService, this._crud, this._storage);

  @override
  Future<Either<SupabaseError, User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final respons = await _authService.logIn(email, password);
      final userId = _authService.currentUser!.id;
      final response = await _crud.getById(
        table: "messenger_users",
        id: userId,
      );
      final user = UserModel.fromJson(response);

      await HiveService.saveUser(user);
      return Right(respons);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, User>> signup({
    required String name,
    required String email,
    required String password,
    required File image,
  }) async {
    try {
      final respons = await _authService.signUp(email, password);
      final myUuid = _authService.currentUser!.id;
      final path = await _storage.uploadImage(
        file: image,
        storageFile: 'users_image',
      );
      final imagePath = _storage.getFileUrl(
        path: path,
        storageFile: 'users_image',
      );

      ///user data as user model
      final UserModel data = UserModel(
        id: myUuid,
        name: name,
        email: email,
        image: imagePath,
        about: "",
        createdAt: DateTime.now().toUtc(),
        lastSeen: DateTime.now().toUtc(),
        isOnLine: false,
        myContacts: [],
      );
      await _crud.post(table: "messenger_users", data: data.toJson());
      await HiveService.saveUser(data);
      return Right(respons);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }
  }
}
