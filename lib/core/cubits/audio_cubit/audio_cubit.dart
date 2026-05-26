import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'audio_state.dart';

class AudioCubit extends Cubit<AudioState> {
  AudioCubit(this._storage) : super(const AudioState());

  final AudioRecorder _recorder = AudioRecorder();
  final SupabaseStorage _storage ;

  Timer? _timer;
  int lastDuration = 0;

  Future<void> startRecording({
    required String chatId,
    required String senderId,
  }) async {
    try {
      // ✅ permission check
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        emit(
          state.copyWith(
            status: RecordingStatus.error,
            errorMessage: "No mic permission",
          ),
        );
        return;
      }

      // ✅ cancel any previous timer
      _timer?.cancel();

      final dir = await getTemporaryDirectory();
      final path =
          "${dir.path}/$chatId-$senderId-${DateTime.now().millisecondsSinceEpoch}.m4a";

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (isClosed) return;

      emit(
        state.copyWith(
          status: RecordingStatus.recording,
          duration: Duration.zero,
        ),
      );

      // ✅ start timer safely
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (isClosed) return;
        emit(state.copyWith(duration: Duration(seconds: timer.tick)));
      });
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: RecordingStatus.error,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }

  Future<String?> stopRecordingOnly() async {
    _timer?.cancel();
    lastDuration = state.duration.inSeconds;

    try {
      if (await _recorder.isRecording()) {
        final path = await _recorder.stop();

        if (path == null || !File(path).existsSync()) return null;

        if (!isClosed) {
          emit(state.copyWith(status: RecordingStatus.uploading));
        }

        return path;
      }
      return null;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(status: RecordingStatus.error));
      }
      return null;
    }
  }

  // ✅ upload في الخلفية
  Future<void> uploadAndNotify({
    required String localPath,
    required String groupId,
    required Function(String uploadedUrl) onUploaded,
  }) async {
    try {
      final uploadedPath = await _storage.uploadAudio(file: File(localPath),storageFile: 'chat-audio');
      final audioUrl = _storage.getFileUrl(path: uploadedPath, storageFile: 'chat-audio');

      if (!isClosed) {
        emit(
          state.copyWith(
            status: RecordingStatus.success,
            duration: Duration.zero,
          ),
        );
      }

      onUploaded(audioUrl);
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: RecordingStatus.error,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }

  /// cancel recording
  Future<void> cancelRecording() async {
    _timer?.cancel();

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}

    if (!isClosed) {
      emit(const AudioState());
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _recorder.dispose();
    return super.close();
  }
}
