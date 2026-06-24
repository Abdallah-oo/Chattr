import 'dart:developer';
import 'dart:io';

import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCrudServices {
  final SupabaseClientManager _clientManager;

  SupabaseCrudServices(this._clientManager);

  SupabaseClient get _client => _clientManager.client;

  // ===================== GET =====================

  Future<List<Map<String, dynamic>>> get({required String table}) {
    return _execute(() async {
      final response = await _client.from(table).select();
      return response;
    }, debugLabel: 'Get');
  }

  Future<Map<String, dynamic>> getById({
    required String table,
    required String id,
  }) {
    return _execute(() async {
      return await _client.from(table).select().eq('id', id).single();
    }, debugLabel: 'GetById');
  }

  Future<Map<String, dynamic>?> getByFilter({
    required String table,
    required String filterColumn,
    required String filterValue,
  }) {
    return _execute(() async {
      return await _client
          .from(table)
          .select()
          .eq(filterColumn, filterValue)
          .maybeSingle();
    }, debugLabel: 'GetByFilter');
  }

  // ===================== POST =====================

  Future<void> postWithoutSelect({
    required String table,
    required Map<String, dynamic> data,
  }) {
    return _execute(() async {
      await _client.from(table).insert(data);
    }, debugLabel: 'PostWithoutSelect');
  }

  Future<Map<String, dynamic>> post({
    required String table,
    required Map<String, dynamic> data,
  }) {
    return _execute(() async {
      return await _client.from(table).insert(data).select().single();
    }, debugLabel: 'Post');
  }

  // ===================== UPDATE =====================

  Future<void> put({
    required String table,
    required Map<String, dynamic> data,
    required String column,
    required dynamic id,
  }) {
    return _execute(() async {
      await _client.from(table).update(data).eq(column, id);
    }, debugLabel: 'Put');
  }

  // ===================== DELETE =====================

  Future<void> delete({
    required String table,
    required column,
    required String id,
  }) {
    return _execute(() async {
      await _client.from(table).delete().eq(column, id);
    }, debugLabel: 'Delete');
  }

  //update fcm token
  // مثال للدالة جوا الـ Service بتاعتك
  Future<void> updateUserFcmToken({
    required String userId,
    required String token,
  }) async {
    try {
      await _client // أو اسم الـ instance بتاعك
          .from('messenger_users')
          .update({'fcm_token': token})
          .eq('id', userId);
      final UserModel? updateUser = await HiveService.getUser(userId);
      await HiveService.saveUser(updateUser!.copyWith(fcmToken: token));
      log('FCM Token updated successfully in Supabase');
    } catch (e) {
      log('Error updating FCM token: $e');
    }
  }

  // ===================== CORE EXECUTOR =====================

  Future<T> _execute<T>(
    Future<T> Function() action, {
    required String debugLabel,
  }) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw SupabaseError(message: e.message);
    } on PostgrestException catch (e) {
      return _handlePostgrestError(e);
    } on SocketException {
      throw SupabaseError(message: 'No internet connection');
    } catch (e) {
      // ignore: avoid_print
      print("this is the error($debugLabel): $e");
      throw SupabaseError(message: 'Unexpected error occurred');
    }
  }

  Never _handlePostgrestError(PostgrestException e) {
    if (e.code == '42501') {
      throw SupabaseError(message: 'Permission denied. Check RLS policies.');
    } else if (e.code == '23505') {
      throw SupabaseError(message: 'Duplicate entry.');
    }

    throw SupabaseError(message: e.message);
  }
}
