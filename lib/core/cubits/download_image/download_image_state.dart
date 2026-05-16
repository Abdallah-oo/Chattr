part of 'download_image_cubit.dart';

@immutable
sealed class DownloadImageState {}

final class DownloadImageInitial extends DownloadImageState {}
final class DownloadImageLoading extends DownloadImageState {
  final double progress;
  DownloadImageLoading({required this.progress});
}
final class DownloadImageSucess extends DownloadImageState {}
final class DownloadImagefailure extends DownloadImageState {
  final String errorMessage;
  DownloadImagefailure({required this.errorMessage});
}


