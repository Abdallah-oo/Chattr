
import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_message_model.dart';
import 'package:path_provider/path_provider.dart';

class ImageMessageWidget extends StatefulWidget {
  const ImageMessageWidget({super.key, required this.imageMessage});
  final dynamic imageMessage;

  @override
  State<ImageMessageWidget> createState() => _ImageMessageWidgetState();
}

class _ImageMessageWidgetState extends State<ImageMessageWidget>
    with AutomaticKeepAliveClientMixin {
  // KeepAlive — يمنع Flutter من dispose الـ widget لما يخرج من الشاشة
  @override
  bool get wantKeepAlive => true;

  String? _localPath;
  bool _hiveLookedUp = false;
  bool _downloadStarted = false;

  // ─── sync resolve — بيشتغل قبل أول frame ────────────────────────
  String? _quickResolve() {
    final content = widget.imageMessage.content as String;
    final modelLocalPath = widget.imageMessage.localPath as String?;

    // temp optimistic — content نفسه local path
    if (content.startsWith('/') && File(content).existsSync()) return content;

    // localPath على الـ model مباشرة
    if (modelLocalPath != null && File(modelLocalPath).existsSync()) {
      return modelLocalPath;
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _localPath = _quickResolve();
    if (_localPath == null) _startAsyncResolve();
  }

  @override
  void didUpdateWidget(ImageMessageWidget old) {
    super.didUpdateWidget(old);

    // لو الـ model جاب localPath جديد — upgrade فوراً
    final newLocalPath = widget.imageMessage.localPath as String?;
    if (_localPath == null &&
        newLocalPath != null &&
        File(newLocalPath).existsSync()) {
      setState(() => _localPath = newLocalPath);
      return;
    }

    // لو الـ content اتغير (temp→URL) — أعد الـ resolve
    final oldContent = old.imageMessage.content as String;
    final newContent = widget.imageMessage.content as String;
    if (oldContent != newContent) {
      _hiveLookedUp = false;
      _downloadStarted = false;
      final quick = _quickResolve();
      if (quick != null) {
        setState(() => _localPath = quick);
      } else {
        _startAsyncResolve();
      }
    }
  }

  Future<void> _startAsyncResolve() async {
    final messageId = widget.imageMessage.messageId as String?;
    final content = widget.imageMessage.content as String;

    // Hive lookup
    if (!_hiveLookedUp && messageId != null) {
      _hiveLookedUp = true;
      final hivePath = widget.imageMessage is PrivateMessageModel
          ? await HiveService.getPrivateMessageLocalPath(messageId)
          : await HiveService.getGroupMessageLocalPath(messageId);
      if (hivePath != null && File(hivePath).existsSync()) {
        if (mounted) setState(() => _localPath = hivePath);
        return;
      }
    }

    // download في الخلفية — الـ build عارض الـ URL في نفس الوقت
    if (!_downloadStarted && messageId != null && content.startsWith('http')) {
      _downloadStarted = true;
      unawaited(_downloadAndCache(content, messageId));
    }
  }

  Future<void> _downloadAndCache(String url, String messageId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final raw = url.split('.').last.split('?').first;
      final ext = ['jpg', 'jpeg', 'png', 'webp'].contains(raw) ? raw : 'jpg';
      final path = '${dir.path}/img_$messageId.$ext';

      if (!File(path).existsSync()) {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) return;
        await File(path).writeAsBytes(res.bodyBytes);
      }

      widget.imageMessage is PrivateMessageModel
          ? await HiveService.savePrivateMessageLocalPath(
              messageId: messageId,
              localPath: path,
            )
          : await HiveService.saveGroupMessageLocalPath(
              messageId: messageId,
              localPath: path,
            );

      if (mounted) setState(() => _localPath = path);
    } catch (e) {
      debugPrint('❌ ImageMessageWidget._downloadAndCache: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // مطلوب مع AutomaticKeepAliveClientMixin

    // ✅ Local file — أسرع وأفضل
    if (_localPath != null) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(_localPath!),
            fit: BoxFit.cover,
            width: double.infinity,
            gaplessPlayback: true,
            cacheWidth:
                800, // يحط الصورة في الـ image cache بـ resolution معقولة
            frameBuilder: (_, child, frame, _) =>
                frame == null ? _Placeholder() : child,
          ),
        ),
      );
    }

    final content = widget.imageMessage.content as String;

    // ✅ URL
    if (content.startsWith('http')) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: content,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (_, _) => _Placeholder(),
            errorWidget: (_, _, _) => _ErrorWidget(),
          ),
        ),
      );
    }

    return _Placeholder();
  }
}

// ─── ثابتة الحجم دايماً عشان الـ container ما يتغيرش ────────────
class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 200,
    width: double.infinity,
    child: Center(
      child: CupertinoActivityIndicator(color: Colors.white54, radius: 9),
    ),
  );
}

class _ErrorWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 200,
    width: double.infinity,
    child: Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.red,
        size: 40,
      ),
    ),
  );
}
