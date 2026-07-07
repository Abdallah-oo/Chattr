import 'dart:io';
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/notification/notification_service.dart';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepoImpl implements AuthRepo {
  final AuthService _authService;
  final SupabaseCrudServices _crud;
  final SupabaseStorage _storage;
  final NotificationService _notificationService;
  final SupabaseClientManager _clientManager;

  AuthRepoImpl(
    this._authService,
    this._crud,
    this._storage,
    this._notificationService,
    this._clientManager,
  );
  SupabaseClient get _client => _clientManager.client;

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
      final token = await _notificationService.getDeviceToken();
      await _crud.updateUserFcmToken(userId: userId, token: token!);
      await HiveService.saveUser(user);
      return Right(respons);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, User?>> signup({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _authService.signUp(email, password);
      final isExistingUnverifiedUser = response.identities?.isEmpty ?? false;

      if (isExistingUnverifiedUser) {
        // الإيميل موجود بالفعل ولسه مش confirmed
        // بدل ما نسيب signUp() يفشل بصمت، نبعتله كود تاني بشكل صريح
        await _client.auth.resend(type: OtpType.signup, email: email);
        return const Right(null);
      }

      return Right(response);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, void>> verifySignupOtp({
    required String email,
    required String otp,
    required String name,
    required File image,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.signup,
      );
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
      final UserModel userData = UserModel(
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
      await sendFCMToken(userData);

      return const Right(null);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, void>> resendSignupOtp({
    required String email,
  }) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email);
      return const Right(null);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, void>> sendPasswordResetOtp({
    required String email,
  }) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const Right(null);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, void>> updatePassword({
    required String newPassword,
  }) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return const Right(null);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, void>> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );
      return const Right(null);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }
  }

  //?helper function
  Future<void> sendFCMToken(UserModel userData) async {
    final fcmToken = await syncFcmToken(userData);
    final userDataWithFCM = userData.copyWith(fcmToken: fcmToken);
    await _crud.post(table: "messenger_users", data: userDataWithFCM.toJson());
    await HiveService.saveUser(userDataWithFCM);
  }

  Future<String> syncFcmToken(UserModel currentUser) async {
    final notificationService = getIt<NotificationService>();
    final String? deviceToken = await notificationService.getDeviceToken();
    return deviceToken ?? '';
  }

  @override
  Future<Either<SupabaseError, Unit>> updateFCM() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final token = await _notificationService.getDeviceToken();
        await _crud.updateUserFcmToken(userId: userId, token: token!);
      }
    } catch (e) {
      Left(SupabaseError(message: '$e'));
    }
    return const Right(unit);
  }
}
