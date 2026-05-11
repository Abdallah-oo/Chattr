import 'dart:io';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';


class SupabaseStorage {
  final _client = SupabaseClientManager.client;
  final String storageFile;

  SupabaseStorage({required this.storageFile});

  // ===================== Public APIs =====================

  Future<String> uploadImage(File file) async {
    return _execute(() => _uploadFile(file));
  }

  Future<String> uploadAudio(File file) async {
    return _execute(() => _uploadFile(file, contentType: 'audio/m4a'));
  }

  Future<String> updateImage(String oldPath, File newFile) async {
    return _execute(() async {
      await deleteFile(oldPath);
      return uploadImage(newFile);
    });
  }

  Future<String> updateAudio(String oldPath, File newFile) async {
    return _execute(() async {
      await deleteFile(oldPath);
      return uploadAudio(newFile);
    });
  }

  Future<void> deleteFile(String path) async {
    return _execute(() async {
      await _client.storage.from(storageFile).remove([path]);
    });
  }

  String getFileUrl(String path) {
    return _client.storage.from(storageFile).getPublicUrl(path);
  }

  // ===================== Core Upload =====================

  Future<String> _uploadFile(File file, {String? contentType}) async {
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
