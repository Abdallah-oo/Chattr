import 'dart:async';
import 'dart:math' as math;

import 'package:chattr/core/cubits/audio_cubit/audio_cubit.dart';
import 'package:chattr/core/cubits/audio_cubit/audio_state.dart';
import 'package:chattr/core/widgets/audio/ui/painters/dashed_ring_painter.dart';
import 'package:chattr/core/widgets/audio/ui/widgets/pulse_ring.dart';
import 'package:chattr/core/widgets/audio/ui/widgets/record_button.dart';
import 'package:chattr/core/widgets/audio/ui/widgets/record_timer_text.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/send_group_message_cubit/send_group_message_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AudioRecordButton extends StatefulWidget {
  final String chatId;
  final String senderId;
  final UserModel sender;
  final bool isGroup;

  const AudioRecordButton({
    super.key,
    required this.chatId,
    required this.senderId,
    required this.sender,
    required this.isGroup,
  });

  @override
  State<AudioRecordButton> createState() => _AudioRecordButtonState();
}

class _AudioRecordButtonState extends State<AudioRecordButton>
    with TickerProviderStateMixin {
  // ✅ Scale animation
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  // ✅ Pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ✅ Ring rotation animation
  late AnimationController _ringController;

  // ✅ Timer
  Timer? _timer;
  int _seconds = 0;

  void _startAnimations() {
    _scaleController.forward();
    _pulseController.repeat(reverse: true);
    _ringController.repeat();
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _stopAnimations() {
    _scaleController.reverse();
    _pulseController.stop();
    _pulseController.reset();
    _ringController.stop();
    _ringController.reset();
    _timer?.cancel();
    setState(() => _seconds = 0);
  }

  //.........................................
  @override
  void initState() {
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    super.initState();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        HapticFeedback.mediumImpact(); //vibrate on start
        _startAnimations();
        context.read<AudioCubit>().startRecording(
          chatId: widget.chatId,
          senderId: widget.senderId,
        );
      },
      onLongPressEnd: (_) async {
        HapticFeedback.lightImpact();
        _stopAnimations();

        final cubit = context.read<AudioCubit>();
        if (cubit.state.status != RecordingStatus.recording) return;

        final localPath = await cubit.stopRecordingOnly();
        if (localPath == null || !context.mounted) return;
        final sendPrivateVoice = widget.isGroup
            ? null
            : context.read<SendPrivateMessageCubit>();
        final sendGroupVoice = widget.isGroup
            ? context.read<SendGroupMessageCubit>()
            : null;
        // ✅ اعرض فوراً بدون URL
        widget.isGroup
            ? sendGroupVoice!.showLocalVoice(
                sender: widget.sender,
                senderId: widget.senderId,
                groupId: widget.chatId,
                audioPath: localPath,
                duration: cubit.lastDuration,
              )
            : sendPrivateVoice!.showLocalVoice(
                sender: widget.sender,
                senderId: widget.senderId,
                chatId: widget.chatId,
                audioPath: localPath,
                duration: cubit.lastDuration,
              );

        // ✅ upload في الخلفية
        unawaited(
          cubit.uploadAndNotify(
            localPath: localPath,
            groupId: widget.chatId,
            onUploaded: (uploadedUrl) {
              widget.isGroup
                  ? sendGroupVoice!.updateVoiceUrl(
                      groupId: widget.chatId,
                      localPath: localPath,
                      uploadedUrl: uploadedUrl,
                    )
                  : sendPrivateVoice!.updateVoiceUrl(
                      chatId: widget.chatId,
                      localPath: localPath,
                      uploadedUrl: uploadedUrl,
                    );
            },
          ),
        );
      },
      child: BlocBuilder<AudioCubit, AudioState>(
        builder: (context, state) {
          final isRecording = state.status == RecordingStatus.recording;

          return AnimatedBuilder(
            animation: Listenable.merge([
              _scaleAnim,
              _pulseAnim,
              _ringController,
            ]),
            builder: (context, _) {
              return SizedBox(
                width: 40,
                height: 50,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerRight,
                  children: [
                    // ✅ Timer text
                    if (isRecording)
                      RecordTimerText(
                        isRecording: isRecording,
                        seconds: _seconds,
                      ),
                    // ✅ Pulse ring
                    if (isRecording) PulseRing(pulseAnim: _pulseAnim),
                    // ✅ Rotating dashed ring
                    if (isRecording)
                      Positioned(
                        right: 0,
                        left: 0,
                        child: Transform.rotate(
                          angle: _ringController.value * 2 * math.pi,
                          child: CustomPaint(
                            size: const Size(46, 46),
                            painter: DashedRingPainter(),
                          ),
                        ),
                      ),

                    RecordButton(
                      scaleAnim: _scaleAnim,
                      isRecording: isRecording,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
