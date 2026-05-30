import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseStorage {
  final SupabaseClientManager _clientManager;
  SupabaseClient get _client => _clientManager.client;
  SupabaseStorage(this._clientManager);

  // ===================== Public APIs =====================

  Future<String> uploadImage({
    required File file,
    required String storageFile,
  }) async {
    return _execute(() => _uploadFile(file: file, storageFile: storageFile));
  }

  Future<String> uploadAudio({
    required File file,
    required String storageFile,
  }) async {
    return _execute(
      () => _uploadFile(
        file: file,
        storageFile: storageFile,
        contentType: 'audio/m4a',
      ),
    );
  }

  Future<String> updateImage({
    required String oldPath,
    required File newFile,
    required String storageFile,
  }) async {
    return _execute(() async {
      await deleteFile(path: oldPath, storageFile: storageFile);
      return uploadImage(file: newFile, storageFile: storageFile);
    });
  }

  Future<String> updateAudio({
    required String oldPath,
    required File newFile,
    required String storageFile,
  }) async {
    return _execute(() async {
      await deleteFile(path: oldPath, storageFile: storageFile);
      return uploadAudio(file: newFile, storageFile: storageFile);
    });
  }

  Future<void> deleteFile({
    required String path,
    required String storageFile,
  }) async {
    return _execute(() async {
      await _client.storage.from(storageFile).remove([path]);
    });
  }

  String getFileUrl({required String path, required String storageFile}) {
    return _client.storage.from(storageFile).getPublicUrl(path);
  }

  // ===================== Core Upload =====================

  Future<String> _uploadFile({
    required File file,
    required String storageFile,
    String? contentType,
  }) async {
    final uuid = const Uuid().v4();
    final extension = file.path.split('.').last;
    final path = "public/$uuid.$extension";

    await _client.storage
        .from(storageFile)
        .upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: contentType ?? 'application/octet-stream',
          ),
        );

    return path;
  }

  // ===================== Error Handler =====================

  Future<T> _execute<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw SupabaseError(message: e.message);
    } on SocketException {
      throw SupabaseError(message: 'No internet connection');
    } catch (_) {
      throw SupabaseError(message: 'Unexpected error occurred');
    }
  }
}
