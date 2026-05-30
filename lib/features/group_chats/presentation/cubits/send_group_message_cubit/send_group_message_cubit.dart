import 'dart:async';
import 'dart:io';

import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/data/repos/send_group_message_repo/send_group_message_repo.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

part 'send_group_message_state.dart';

class SendGroupMessageCubit extends Cubit<SendGroupMessageState> {
  SendGroupMessageCubit({
    required this.fetchCubit,
    required SendGroupMessageRepo repo,
  }) : _repo = repo,
       super(SendGroupMessageInitial());

  final FetchGroupMessagesCubit fetchCubit;
  final SendGroupMessageRepo _repo;

  final Set<String> _inFlight = {};
  DateTime? _lastTextSend;

  // ─────────────────────────────────────────────────────────────────
  // SEND TEXT
  // ─────────────────────────────────────────────────────────────────

  Future<void> sendTextMessage({
    required String message,
    required UserModel sender,
    required String senderId,
    required String groupId,
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

    final temp = GroupMessageModel(
      tempId: tempId,
      status: GroupMessageStatus.sending,
      groupId: groupId,
      senderId: senderId,
      sender: sender,
      messageType: GroupMessageType.text,
      content: trimmed,
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(groupId: groupId, message: temp);
    emit(SendGroupMessageSuccess());

    final result = await _repo.sendMessage(temp);
    result.fold(
      (err) {
        fetchCubit.markMessageFailed(groupId: groupId, tempId: tempId);
        emit(SendGroupMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          groupId: groupId,
          tempId: tempId,
          serverMessage: server.copyWith(createdAt: temp.createdAt),
        );
      },
    );

    _inFlight.remove(tempId);
  }

  // ─────────────────────────────────────────────────────────────────
  // SEND IMAGE
  // ─────────────────────────────────────────────────────────────────

  Future<void> sendImage({
    required File? imageFile,
    required UserModel sender,
    required String senderId,
    required String groupId,
  }) async {
    if (imageFile == null) return;

    final tempId = const Uuid().v4();
    _inFlight.add(tempId);

    final temp = GroupMessageModel(
      tempId: tempId,
      status: GroupMessageStatus.sending,
      groupId: groupId,
      senderId: senderId,
      sender: sender,
      messageType: GroupMessageType.image,
      content: imageFile.path,
      localPath: imageFile.path,
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(groupId: groupId, message: temp);
    emit(SendGroupMessageSuccess());

    unawaited(
      _uploadAndSend(
        tempId: tempId,
        temp: temp,
        imageFile: imageFile,
        groupId: groupId,
      ),
    );
  }

  Future<void> _uploadAndSend({
    required String tempId,
    required GroupMessageModel temp,
    required File imageFile,
    required String groupId,
  }) async {
    final uploadResult = await _repo.uploadImage(imageFile);

    uploadResult.fold(
      (err) {
        fetchCubit.markMessageFailed(groupId: groupId, tempId: tempId);
        emit(SendGroupMessageFailure(errorMessage: err.message));
        _inFlight.remove(tempId);
      },
      (url) async {
        final sendResult = await _repo.sendMessage(temp.copyWith(content: url));
        sendResult.fold(
          (err) {
            fetchCubit.markMessageFailed(groupId: groupId, tempId: tempId);
            emit(SendGroupMessageFailure(errorMessage: err.message));
          },
          (server) {
            fetchCubit.replaceTempMessage(
              groupId: groupId,
              tempId: tempId,
              serverMessage: server.copyWith(
                createdAt: temp.createdAt,
                localPath: imageFile.path,
              ),
            );
          },
        );
        _inFlight.remove(tempId);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // SEND VOICE
  // ─────────────────────────────────────────────────────────────────

  void showLocalVoice({
    required UserModel sender,
    required String senderId,
    required String groupId,
    required String audioPath,
    required int duration,
  }) {
    _inFlight.add(audioPath);

    final temp = GroupMessageModel(
      tempId: audioPath,
      status: GroupMessageStatus.sending,
      groupId: groupId,
      senderId: senderId,
      sender: sender,
      messageType: GroupMessageType.voice,
      content: audioPath,
      mediaDuration: duration,
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(groupId: groupId, message: temp);
  }

  Future<void> updateVoiceUrl({
    required String groupId,
    required String localPath,
    required String uploadedUrl,
  }) async {
    final messages = fetchCubit.getMessages(groupId);
    if (messages == null) return;

    final idx = messages.indexWhere((m) => m.tempId == localPath);
    if (idx == -1) return;

    final temp = messages[idx];
    final result = await _repo.sendMessage(temp.copyWith(content: uploadedUrl));

    result.fold(
      (err) {
        fetchCubit.markMessageFailed(groupId: groupId, tempId: localPath);
        emit(SendGroupMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          groupId: groupId,
          tempId: localPath,
          serverMessage: server.copyWith(
            createdAt: temp.createdAt,
            localPath: localPath,
          ),
        );
        emit(SendGroupMessageSuccess());
      },
    );

    _inFlight.remove(localPath);
  }

  // ─────────────────────────────────────────────────────────────────
  // RETRY
  // ─────────────────────────────────────────────────────────────────

  Future<void> retryMessage(GroupMessageModel failed) async {
    if (failed.status != GroupMessageStatus.failed) return;
    if (_inFlight.contains(failed.tempId)) return;

    _inFlight.add(failed.tempId);

    fetchCubit.replaceTempMessage(
      groupId: failed.groupId,
      tempId: failed.tempId,
      serverMessage: failed.copyWith(status: GroupMessageStatus.sending),
    );

    final result = await _repo.sendMessage(
      failed.copyWith(messageId: null, status: GroupMessageStatus.sending),
    );

    result.fold(
      (err) {
        fetchCubit.markMessageFailed(
          groupId: failed.groupId,
          tempId: failed.tempId,
        );
        emit(SendGroupMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          groupId: failed.groupId,
          tempId: failed.tempId,
          serverMessage: server.copyWith(createdAt: failed.createdAt),
        );
        emit(SendGroupMessageSuccess());
      },
    );

    _inFlight.remove(failed.tempId);
  }

  Future<void> retryDelete({
    required String groupId,
    required GroupMessageModel message,
  }) async {
    if (message.status != GroupMessageStatus.deleteFailed) return;
    await fetchCubit.deleteGroupMessages(groupId: groupId, messages: [message]);
  }

  Future<void> retryEditMessage({
    required String groupId,
    required GroupMessageModel message,
    required String content,
  }) async {
    if (message.status != GroupMessageStatus.editingFaild) return;
    await fetchCubit.editMessageGroup(
      groupId: groupId,
      message: message,
      content: content,
    );
  }
}
