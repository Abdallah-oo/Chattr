import 'dart:async';
import 'dart:io';

import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

part 'send_private_message_state.dart';

class SendPrivateMessageCubit extends Cubit<SendPrivateMessageState> {
  SendPrivateMessageCubit({
    required this.fetchCubit,
    required SendPrivateMessageRepo repo,
  }) : _repo = repo,
       super(SendPrivateMessageInitial());

  final FetchPrivateMessagesCubit fetchCubit;
  final SendPrivateMessageRepo _repo;

  final Set<String> _inFlight = {};
  DateTime? _lastTextSend;

  // ─── SEND TEXT ───────────────────────────────────────────────────

  Future<void> sendTextMessage({
    required String message,
    required UserModel sender,
    required String senderId,
    required String chatId,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    if (_lastTextSend != null &&
        now.difference(_lastTextSend!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastTextSend = now;

    final tempId = const Uuid().v4();
    if (_inFlight.contains(tempId)) return;
    _inFlight.add(tempId);

    final temp = PrivateMessageModel(
      tempId: tempId,
      privateMessageStatus: PrivateMessageStatus.sending,
      chatId: chatId,
      senderId: senderId,
      sender: sender,
      privateMessageType: PrivateMessageType.text,
      content: trimmed,
      createdAt: DateTime.now(),
      read: false,
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(chatId: chatId, message: temp);
    emit(SendPrivateMessageSuccess());

    final result = await _repo.sendMessage(temp);

    result.fold(
      (err) {
        fetchCubit.markMessageFailed(chatId: chatId, tempId: tempId);
        emit(SendPrivateMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          chatId: chatId,
          tempId: tempId,
          serverMessage: server.copyWith(createdAt: temp.createdAt),
        );
      },
    );

    _inFlight.remove(tempId);
  }

  // ─── SEND IMAGE ──────────────────────────────────────────────────

  Future<void> sendImage({
    required File imageFile,
    required UserModel sender,
    required String senderId,
    required String chatId,
  }) async {
    final tempId = const Uuid().v4();
    _inFlight.add(tempId);

    final temp = PrivateMessageModel(
      tempId: tempId,
      privateMessageStatus: PrivateMessageStatus.sending,
      chatId: chatId,
      senderId: senderId,
      sender: sender,
      privateMessageType: PrivateMessageType.image,
      content: imageFile.path,
      localPath: imageFile.path,
      createdAt: DateTime.now(),
      read: false,
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(chatId: chatId, message: temp);
    emit(SendPrivateMessageSuccess());

    unawaited(
      _uploadAndSendImage(
        tempId: tempId,
        temp: temp,
        imageFile: imageFile,
        chatId: chatId,
      ),
    );
  }

  Future<void> _uploadAndSendImage({
    required String tempId,
    required PrivateMessageModel temp,
    required File imageFile,
    required String chatId,
  }) async {
    final uploadResult = await _repo.uploadImage(imageFile);

    await uploadResult.fold(
      (err) async {
        fetchCubit.markMessageFailed(chatId: chatId, tempId: tempId);
        emit(SendPrivateMessageFailure(errorMessage: err.message));
      },
      (url) async {
        final sendResult = await _repo.sendMessage(temp.copyWith(content: url));
        sendResult.fold(
          (err) {
            fetchCubit.markMessageFailed(chatId: chatId, tempId: tempId);
            emit(SendPrivateMessageFailure(errorMessage: err.message));
          },
          (server) {
            fetchCubit.replaceTempMessage(
              chatId: chatId,
              tempId: tempId,
              serverMessage: server.copyWith(
                createdAt: temp.createdAt,
                localPath: imageFile.path,
              ),
            );
          },
        );
      },
    );

    _inFlight.remove(tempId);
  }

  // ─── SEND VOICE ──────────────────────────────────────────────────

  void showLocalVoice({
    required UserModel sender,
    required String senderId,
    required String chatId,
    required String audioPath,
    required int duration,
  }) {
    _inFlight.add(audioPath);

    final temp = PrivateMessageModel(
      tempId: audioPath,
      privateMessageStatus: PrivateMessageStatus.sending,
      chatId: chatId,
      senderId: senderId,
      sender: sender,
      read: false,
      privateMessageType: PrivateMessageType.voice,
      content: audioPath,
      mediaDuration: duration,
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(chatId: chatId, message: temp);
  }

  Future<void> updateVoiceUrl({
    required String chatId,
    required String localPath,
    required String uploadedUrl,
  }) async {
    final messages = fetchCubit.getMessages(chatId);
    if (messages == null) return;

    final idx = messages.indexWhere((m) => m.tempId == localPath);
    if (idx == -1) return;

    final temp = messages[idx];
    final result = await _repo.sendMessage(temp.copyWith(content: uploadedUrl));

    result.fold(
      (err) {
        fetchCubit.markMessageFailed(chatId: chatId, tempId: localPath);
        emit(SendPrivateMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          chatId: chatId,
          tempId: localPath,
          serverMessage: server.copyWith(
            createdAt: temp.createdAt,
            localPath: localPath,
          ),
        );
        emit(SendPrivateMessageSuccess());
      },
    );

    _inFlight.remove(localPath);
  }

  // ─── RETRY ───────────────────────────────────────────────────────

  Future<void> retryMessage(PrivateMessageModel failed) async {
    if (failed.privateMessageStatus != PrivateMessageStatus.failed) return;
    if (_inFlight.contains(failed.tempId)) return;

    _inFlight.add(failed.tempId);

    fetchCubit.replaceTempMessage(
      chatId: failed.chatId,
      tempId: failed.tempId,
      serverMessage: failed.copyWith(
        privateMessageStatus: PrivateMessageStatus.sending,
      ),
    );

    final result = await _repo.sendMessage(
      failed.copyWith(
        messageId: null,
        privateMessageStatus: PrivateMessageStatus.sending,
      ),
    );

    result.fold(
      (err) {
        fetchCubit.markMessageFailed(
          chatId: failed.chatId,
          tempId: failed.tempId,
        );
        emit(SendPrivateMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          chatId: failed.chatId,
          tempId: failed.tempId,
          serverMessage: server.copyWith(createdAt: failed.createdAt),
        );
        emit(SendPrivateMessageSuccess());
      },
    );

    _inFlight.remove(failed.tempId);
  }

  Future<void> retryDelete({
    required String chatId,
    required PrivateMessageModel message,
  }) async {
    if (message.privateMessageStatus != PrivateMessageStatus.deleteFailed) {
      return;
    }
    await fetchCubit.deletePrivateMessages(chatId: chatId, messages: [message]);
  }

  Future<void> retryEditMessage({
    required String chatId,
    required PrivateMessageModel message,
    required String content,
  }) async {
    if (message.privateMessageStatus != PrivateMessageStatus.editingFaild) {
      return;
    }
    await fetchCubit.editPrivateMessage(
      chatId: chatId,
      message: message,
      content: content,
    );
  }
}
