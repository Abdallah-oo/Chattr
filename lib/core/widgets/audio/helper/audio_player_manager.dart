
import 'package:just_audio/just_audio.dart';

class AudioPlayerManager {
  AudioPlayerManager._();
  static final AudioPlayerManager instance = AudioPlayerManager._();

  AudioPlayer? _currentPlayer;
  String? _currentMessageId;

  // ✅ لما تشغل player جديد - وقف القديم
  Future<void> play({
    required String messageId,
    required AudioPlayer player,
  }) async {
 // وقف الـ player القديم لو مختلف
  if (_currentPlayer != null && _currentPlayer != player) {
    await _currentPlayer!.pause();
  }

  _currentPlayer = player;
  _currentMessageId = messageId;
  await player.play(); // ✅ شغّل دايماً
  }

  void unregister(String messageId) {
    if (_currentMessageId == messageId) {
      _currentPlayer = null;
      _currentMessageId = null;
    }
  }
}