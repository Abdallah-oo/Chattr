import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

part 'download_image_state.dart';

enum GalleryPermissionStatus { granted, permanentlyDenied }

class DownloadImageCubit extends Cubit<DownloadImageState> {
  DownloadImageCubit() : super(DownloadImageInitial());

  final Dio _dio = Dio();

  bool _isValidImageUrl(String url) {
    return url.endsWith(".jpg") ||
        url.endsWith(".png") ||
        url.endsWith(".jpeg") ||
        url.endsWith(".webp");
  }

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return "Connection timeout";

      case DioExceptionType.receiveTimeout:
        return "Request took too long";

      case DioExceptionType.badResponse:
        return "Failed to load image from server";

      case DioExceptionType.connectionError:
        return "Check your internet connection";

      default:
        return "An unexpected error occurred";
    }
  }

  Future<GalleryPermissionStatus> _checkGalleryPermission() async {
    final hasAccess = await Gal.hasAccess();

    if (hasAccess) return GalleryPermissionStatus.granted;

    final requested = await Gal.requestAccess();

    if (requested) return GalleryPermissionStatus.granted;

    return GalleryPermissionStatus.permanentlyDenied;
  }

  Future<void> downloadImage(String imageUrl) async {
    if (state is DownloadImageLoading) return;

    emit(DownloadImageLoading(progress: 0));

    try {
      if (!_isValidImageUrl(imageUrl)) {
        emit(DownloadImagefailure(errorMessage: 'The image link is invalid'));
        return;
      }

      /// ✅ Check Permission
      final permissionStatus = await _checkGalleryPermission();

      if (permissionStatus == GalleryPermissionStatus.permanentlyDenied) {
        emit(
          DownloadImagefailure(
            errorMessage:
                "Permission permanently denied. Please enable it in Settings",
          ),
        );
        return;
      }

      final hasAccess = await Gal.hasAccess();

      if (!hasAccess) {
        emit(DownloadImagefailure(errorMessage: "Permission denied. Please enable it in Settings"));
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.jpg';


      if (imageUrl.startsWith('/')) {
        emit(DownloadImageLoading(progress: 0));
        await Gal.putImage(imageUrl);
        emit(DownloadImageSucess());
        return;
      }  
      
      await _dio.download(
        imageUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            emit(DownloadImageLoading(progress: progress));
          }
        },
      );
  

      final file = File(filePath);
      if (!file.existsSync()) {
        emit(DownloadImagefailure(errorMessage: "Failed to save the image"));
        return;
      }

      await Gal.putImage(filePath);

      await file.delete();

      emit(DownloadImageSucess());
    } on DioException catch (e) {
      emit(DownloadImagefailure(errorMessage: _handleDioError(e)));
    } catch (e) {
      emit(DownloadImagefailure(errorMessage: "$e"));
    }
  }
}
