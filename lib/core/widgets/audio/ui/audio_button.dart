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
import 'package:permission_handler/permission_handler.dart';

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
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _ringController;

  Timer? _timer;
  int _seconds = 0;
  bool _permissionGranted = false;

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

  @override
  void initState() {
    super.initState();

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

    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    if (mounted) setState(() => _permissionGranted = status.isGranted);
  }

  // ✅ الدالة الوحيدة للـ long press
  // لو permission مش موجود: نطلبه وننتهي — مش بيحصل recording ولا animation
  // لو permission موجود: نبدأ عادي
  Future<void> _onLongPressStart() async {
    if (!_permissionGranted) {
      // ✅ بنطلب الـ permission هنا بـ permission_handler مش بـ record
      // بترجع بعد ما اليوزر يختار (grant/deny) — مش بتفضل شغالة
      final status = await Permission.microphone.request();
      if (mounted) setState(() => _permissionGranted = status.isGranted);
      // الـ long press خلص هنا — الـ onLongPressEnd هيشتغل بس الـ recording مش بدأ
      return;
    }

    // ✅ permission موجود — ابدأ عادي
    HapticFeedback.mediumImpact();
    _startAnimations();
    if (!mounted) return;
    context.read<AudioCubit>().startRecording(
      chatId: widget.chatId,
      senderId: widget.senderId,
    );
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
      onLongPressStart: (_) => _onLongPressStart(),
      onLongPressEnd: (_) async {
        HapticFeedback.lightImpact();
        _stopAnimations();

        // ✅ لو الـ recording مبدأش (مثلاً بعد permission request)، مش بيحصل حاجة
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
                    if (isRecording)
                      RecordTimerText(
                        isRecording: isRecording,
                        seconds: _seconds,
                      ),
                    if (isRecording) PulseRing(pulseAnim: _pulseAnim),
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
