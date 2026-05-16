import 'package:equatable/equatable.dart';

enum RecordingStatus { idle, recording, uploading, success, locked, error }

class AudioState extends Equatable {
  final RecordingStatus status;
  final Duration duration;
  final String? errorMessage;


  const AudioState({
    this.status = RecordingStatus.idle,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  AudioState copyWith({
    RecordingStatus? status,
    Duration? duration,
    String? errorMessage,
  }) {
    return AudioState(
      status: status ?? this.status,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, duration, errorMessage];
}