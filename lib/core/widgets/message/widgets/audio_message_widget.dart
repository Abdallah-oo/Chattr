import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:messenger_clone0/core/helpers/snack_bar.dart';
import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/utils/extensions/responsive.dart';
import 'package:messenger_clone0/core/widgets/audio/helper/audio_player_manager.dart';
import 'package:messenger_clone0/core/widgets/audio/ui/painters/waveform_painter.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_message_model.dart';
import 'package:path_provider/path_provider.dart';

class AudioMessageWidget extends StatefulWidget {
  const AudioMessageWidget({super.key, required this.audioMessage});
  final dynamic audioMessage;

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget>
    with TickerProviderStateMixin {
  late AudioPlayer _player;
  bool isPlaying = false;
  bool isLoading = true;
  bool hasError = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _durationSub;

  // ✅ Animation controllers
  late AnimationController _waveController;
  late AnimationController _playButtonController;
  late Animation<double> _playButtonScale;

  //...........................................
  Future<void> _initAudio() async {
    try {
      final content = widget.audioMessage.content;
      final messageId = widget.audioMessage.messageId;

      if (content.startsWith('/')) {
        await _player.setFilePath(content);
        if (!mounted) return;
        setState(() => isLoading = false);
        _setupStreams();
        return;
      }

      if (messageId != null) {
        final localPath = widget.audioMessage is PrivateMessageModel
            ? await HiveService.getPrivateMessageLocalPath(messageId)
            : await HiveService.getGroupMessageLocalPath(messageId);

        if (localPath != null && File(localPath).existsSync()) {
          await _player.setFilePath(localPath);
          if (!mounted) return;
          setState(() {
            isLoading = false;
            duration = _player.duration ?? duration;
          });
          _setupStreams();
          return;
        }
      }

      await _player.setUrl(content);
      if (!mounted) return;
      setState(() {
        isLoading = false;
        duration = _player.duration ?? duration;
      });
      _setupStreams();

      if (messageId != null) {
        unawaited(_downloadAndCache(content, messageId));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  Future<void> _downloadAndCache(String url, String messageId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/audio_$messageId.m4a';

      if (File(localPath).existsSync()) {
        widget.audioMessage is PrivateMessageModel
            ? await HiveService.savePrivateMessageLocalPath(
                messageId: messageId,
                localPath: localPath,
              )
            : await HiveService.saveGroupMessageLocalPath(
                messageId: messageId,
                localPath: localPath,
              );
        return;
      }

      final response = await http.get(Uri.parse(url));

      await File(localPath).writeAsBytes(response.bodyBytes);

      widget.audioMessage is PrivateMessageModel
          ? await HiveService.savePrivateMessageLocalPath(
              messageId: messageId,
              localPath: localPath,
            )
          : await HiveService.saveGroupMessageLocalPath(
              messageId: messageId,
              localPath: localPath,
            );
    } catch (e) {
      if (!mounted) return;
      final message = e is http.ClientException
          ? "Network error while loading audio."
          : "Failed to load audio.";
      CustomSnackBar.error(context, message);
    }
  }

  //................................
  void _setupStreams() {
    _durationSub = _player.durationStream.listen((d) {
      if (!mounted) return;
      if (d != null) setState(() => duration = d);
    });

    _positionSub = _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => position = pos);
    });

    _stateSub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => isPlaying = s.playing);
      if (s.playing) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
        setState(() => position = Duration.zero);
      }
    });
  }

  void _togglePlay() async {
    _playButtonController.forward().then(
      (_) => _playButtonController.reverse(),
    );

    if (isPlaying) {
      await _player.pause();
      AudioPlayerManager.instance.unregister(
        widget.audioMessage.messageId ?? widget.audioMessage.tempId,
      );
    } else {
      // ✅ هيوقف أي player تاني تلقائياً
      await AudioPlayerManager.instance.play(
        messageId: widget.audioMessage.messageId ?? widget.audioMessage.tempId,
        player: _player,
      );
    }
  }

  double get _progress {
    if (duration.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String formatTime(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$min:$sec";
  }

  //...........................................
  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _playButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _playButtonScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _playButtonController, curve: Curves.easeOut),
    );

    _player = AudioPlayer();

    if (widget.audioMessage.mediaDuration != null) {
      duration = Duration(seconds: widget.audioMessage.mediaDuration!);
    }

    final content = widget.audioMessage.content;

    // ✅ لو local file أو عنده localPath في الـ message - مش محتاج loading
    // لو URL بس - loading
    isLoading =
        !content.startsWith('/') &&
        widget.audioMessage.localPath == null &&
        widget.audioMessage.messageId != null;

    _initAudio();
  }

  @override
  void dispose() {
    AudioPlayerManager.instance.unregister(
      widget.audioMessage.messageId ?? widget.audioMessage.tempId,
    );
    _positionSub?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _waveController.dispose();
    _playButtonController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waveFormWidth = context.responsiveWidth(
      percentage: 0.23,
      min: context.screenWidth * 0.15,
      max: context.screenWidth * 0.25,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ زرار التشغيل مع animation
        ScaleTransition(
          scale: _playButtonScale,
          child: GestureDetector(
            onTap: isLoading || hasError ? null : _togglePlay,
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: hasError
                    ? const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 22,
                      )
                    : isLoading
                    ? SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          key: ValueKey(isPlaying),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
              ),
            ),
          ),
        ),

        Gap(12),

        // ✅ الوسط - موجات + progress + وقت
        SizedBox(
          width: waveFormWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Waveform + progress
              SizedBox(
                height: 35,

                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(double.infinity, 32),
                      painter: WaveformPainter(
                        progress: _progress,
                        animValue: _waveController.value,
                        isPlaying: isPlaying,
                      ),
                    );
                  },
                ),
              ),

              Gap(5),

              // ✅ الوقت
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomText(
                    text: formatTime(position),
                         style: AppTextStyles.bodySmall,
                  ),
                  CustomText(
                    text: formatTime(duration),
                     style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
