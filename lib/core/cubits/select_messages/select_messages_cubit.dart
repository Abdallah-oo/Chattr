import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'select_messages_state.dart';

class SelectMessagesCubit extends Cubit<SelectMessagesState> {
  SelectMessagesCubit() : super(SelectMessagesInitial());

  final Set<String> _selectedIds = {};
  final List<dynamic> _selectedMessages = [];

  List<dynamic> get selectedMessages => List.unmodifiable(_selectedMessages);

  bool isSelected(dynamic message) {
    final id = message.messageId ?? message.tempId;
    return _selectedIds.contains(id);
  }

  void selectMessage(dynamic message) {
    final id = message.messageId ?? message.tempId;

    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      _selectedMessages.removeWhere((m) => (m.messageId ?? m.tempId) == id);
      emit(RemoveSelectMessages());
    } else {
      _selectedIds.add(id);
      _selectedMessages.add(message);
      emit(AddSelectMessages());
    }
  }

  void copyMessages() {
    final text = _selectedMessages.map((e) => e.content).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    _clear();
    emit(AddSelectMessages());
  }

  void clearSelection() {
    _clear();
    emit(ClearSelection());
  }

  bool containMedia() {
    if (_selectedMessages[0] is PrivateMessageModel) {
      if (_selectedMessages.any(
        (m) => m.privateMessageType != PrivateMessageType.text,
      )) {
        return true;
      }
    } else if (_selectedMessages[0] is GroupMessageModel) {
      if (_selectedMessages.any(
        (m) => m.messageType != GroupMessageType.text,
      )) {
        return true;
      }
    }

    return false;
  }

  void _clear() {
    _selectedIds.clear();
    _selectedMessages.clear();
  }
}
