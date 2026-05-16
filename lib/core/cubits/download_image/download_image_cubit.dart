

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
        return "انتهت مهلة الاتصال";

      case DioExceptionType.receiveTimeout:
        return "التحميل استغرق وقت طويل";

      case DioExceptionType.badResponse:
        return "فشل تحميل الصورة من السيرفر";

      case DioExceptionType.connectionError:
        return "تأكد من اتصال الإنترنت";

      default:
        return "حدث خطأ غير متوقع";
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
        emit(DownloadImagefailure(errorMessage: "رابط الصورة غير صالح"));
        return;
      }

      /// ✅ Check Permission
      final permissionStatus = await _checkGalleryPermission();

      if (permissionStatus == GalleryPermissionStatus.permanentlyDenied) {
        emit(
          DownloadImagefailure(
            errorMessage: "تم رفض الصلاحية نهائياً، فعلها من الإعدادات",
          ),
        );
        return;
      }

      final hasAccess = await Gal.hasAccess();

      if (!hasAccess) {
        emit(DownloadImagefailure(errorMessage: "تم رفض صلاحية الوصول للصور"));
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.jpg';

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
        emit(DownloadImagefailure(errorMessage: "فشل حفظ الصورة"));
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
