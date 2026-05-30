import 'package:chattr/core/services/hive/hive_type_ids.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'private_message_model.g.dart';

@HiveType(typeId: HiveTypeIds.privateMessageStatus)
enum PrivateMessageStatus {
  @HiveField(0)
  sending,
  @HiveField(1)
  sent,
  @HiveField(2)
  failed,
  @HiveField(3)
  deleting,
  @HiveField(4)
  deleteFailed,
  @HiveField(5)
  editing,
  @HiveField(6)
  editingFaild,
}

@HiveType(typeId: HiveTypeIds.privateMessageType)
enum PrivateMessageType {
  @HiveField(0)
  text,
  @HiveField(1)
  image,
  @HiveField(2)
  video,
  @HiveField(3)
  voice,
}

extension MessageTypeParser on String {
  PrivateMessageType toPrivateMessageType() {
    switch (this) {
      case 'text':
        return PrivateMessageType.text;
      case 'image':
        return PrivateMessageType.image;
      case 'video':
        return PrivateMessageType.video;
      case 'voice':
        return PrivateMessageType.voice;
      default:
        return PrivateMessageType.text;
    }
  }
}

extension MessageTypeToJson on PrivateMessageType {
  String toJson() => name;
}

@HiveType(typeId: HiveTypeIds.privateMessages)
class PrivateMessageModel {
  @HiveField(0)
  final String tempId;

  @HiveField(1)
  final String? messageId;

  @HiveField(2)
  final String chatId;

  @HiveField(3)
  final String senderId;

  @HiveField(4)
  final PrivateMessageStatus privateMessageStatus;

  @HiveField(5)
  final PrivateMessageType privateMessageType;

  @HiveField(6)
  final String content;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final bool isDeleted;

  @HiveField(9)
  final bool? read;

  @HiveField(10)
  final UserModel? sender;

  @HiveField(11) // ← جديد
  final String? localPath;
  @HiveField(12)
  final int? mediaDuration;

  PrivateMessageModel({
    required this.tempId,
    this.messageId,
    required this.chatId,
    required this.senderId,

    required this.privateMessageStatus,
    required this.privateMessageType,
    required this.content,
    required this.createdAt,
    required this.isDeleted,
    this.read,
    this.sender,
    this.localPath,
    this.mediaDuration,
  });

  factory PrivateMessageModel.fromJson(Map<String, dynamic> json) {
    return PrivateMessageModel(
      tempId:
          json['temp_id'] ??
          const Uuid().v4(), // لو ما في temp_id، نولد واحد جديد
      messageId: json['message_id'],
      chatId: json['chat_id'],
      senderId: json['sender_id'],
      privateMessageStatus: PrivateMessageStatus.sent,
      privateMessageType: (json['message_type'] as String)
          .toPrivateMessageType(),
      content: json['content'] ?? '',
      mediaDuration: json['media_duration'],
      createdAt: DateTime.parse(json['created_at']),
      isDeleted: json['is_deleted'] ?? false,
      read: json['read'] ?? false,
      sender: null, // لاحقًا تحط بيانات UserModel لو متاحة
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temp_id': tempId,
      'chat_id': chatId,
      'sender_id': senderId,
      'media_duration': mediaDuration,
      'message_type': privateMessageType.toJson(),
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'is_deleted': isDeleted,
      'read': read,
    };
  }

  PrivateMessageModel copyWith({
    String? tempId,
    String? messageId,
    String? content,
    PrivateMessageStatus? privateMessageStatus,
    bool? isDeleted,
    bool? read,
    UserModel? sender,
    String? localPath,
    DateTime? createdAt,
    int? mediaDuration,
  }) {
    return PrivateMessageModel(
      tempId: tempId ?? this.tempId,
      messageId: messageId ?? this.messageId,
      chatId: chatId,
      senderId: senderId,
      privateMessageStatus: privateMessageStatus ?? this.privateMessageStatus,
      privateMessageType: privateMessageType,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      read: read ?? this.read,
      sender: sender ?? this.sender,
      localPath: localPath ?? this.localPath,
      mediaDuration: mediaDuration ?? this.mediaDuration,
    );
  }
}
