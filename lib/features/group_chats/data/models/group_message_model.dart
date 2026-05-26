import 'package:hive/hive.dart';
import 'package:messenger_clone0/core/services/hive/hive_type_ids.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';


part 'group_message_model.g.dart';

@HiveType(typeId: HiveTypeIds.groupMessageStatus)
enum GroupMessageStatus {
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

@HiveType(typeId: HiveTypeIds.groupMessageType)
enum GroupMessageType {
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
  GroupMessageType toMessageType() {
    switch (this) {
      case 'text':
        return GroupMessageType.text;

      case 'image':
        return GroupMessageType.image;

      case 'video':
        return GroupMessageType.video;

      case 'voice':
        return GroupMessageType.voice;

      default:
        return GroupMessageType.text;
    }
  }
}

extension MessageTypeToJson on GroupMessageType {
  String toJson() => name;
}

@HiveType(typeId: HiveTypeIds.groupMessages)
class GroupMessageModel {
  @HiveField(0)
  final String tempId;
  @HiveField(1) // UI only
  final String? messageId;
  @HiveField(2) // server
  final GroupMessageStatus status;
  @HiveField(3)
  final String groupId;
  @HiveField(4)
  final String senderId;
  @HiveField(5)
  final GroupMessageType messageType;
  @HiveField(6)
  final String content;
  @HiveField(7)
  final int? mediaDuration;
  @HiveField(8)
  final DateTime createdAt;
  @HiveField(9)
  final bool isDeleted;
  @HiveField(10)
  final UserModel? sender;
  @HiveField(11) // ← جديد
  final String? localPath;

  GroupMessageModel({
    required this.tempId,
    this.messageId,
    this.localPath,
    required this.status,
    required this.groupId,
    required this.senderId,
    required this.messageType,
    required this.content,
    required this.createdAt,
    required this.isDeleted,

    required this.sender,
    this.mediaDuration,
  });

  factory GroupMessageModel.fromJson(Map<String, dynamic> json) {
    return GroupMessageModel(
      tempId: json['temp_id'], // مؤقت للـ replace فقط
      messageId: json['message_id'],
      status: GroupMessageStatus.sent,
      groupId: json['group_id'],
      senderId: json['sender_id'],
      messageType: (json['message_type'] as String).toMessageType(),
      content: json['content'],
      mediaDuration: json['media_duration'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isDeleted: json['is_deleted'],
      sender: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temp_id': tempId,
      'group_id': groupId,
      'sender_id': senderId,
      'message_type': messageType.toJson(),
      'content': content,
      'media_duration': mediaDuration,
      'created_at': createdAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  GroupMessageModel copyWith({
    String? messageId,
    String? localPath,
    DateTime? createdAt,
    int? mediaDuration,
    GroupMessageStatus? status,
    String? content,
    bool? isDeleted,
  }) {
    return GroupMessageModel(
      tempId: tempId,
      messageId: messageId ?? this.messageId,
      status: status ?? this.status,
      groupId: groupId,
      senderId: senderId,
      messageType: messageType,
      content: content ?? this.content,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      localPath: localPath ?? this.localPath,
      sender: sender,
    );
  }
}
