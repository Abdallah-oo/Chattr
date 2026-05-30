
import 'package:chattr/core/services/hive/hive_type_ids.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:hive/hive.dart';

part 'private_chat_model.g.dart';

@HiveType(typeId: HiveTypeIds.privateChats)
class PrivateChatModel {
  @HiveField(0)
  final String? chatId;

  @HiveField(1)
  final List<String>? members;

  @HiveField(2)
  final String? lastMessage;

  @HiveField(3)
  final DateTime? lastMessageTime;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final UserModel? friend;

  @HiveField(6)
  final String? membersId;
  @HiveField(7)
  final String? lastMessageSenderId;

  // مش محتاج HiveField — بيتحسب runtime بس
  final int unreadCount;

  PrivateChatModel({
    this.chatId,
    required this.members,
    required this.membersId,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.createdAt,
    this.lastMessageSenderId,
    this.friend,
    this.unreadCount = 0,
  });

  factory PrivateChatModel.fromJson(
    Map<String, dynamic> json,
    UserModel friend,
  ) {
    return PrivateChatModel(
      chatId: json['chat_id'] ?? '',
      membersId: json['members_id'] ?? '',
      members: (json['members'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      lastMessage: json['last_message'] ?? '',
      lastMessageTime: DateTime.tryParse(json['last_message_time'] ?? ''),
      createdAt: DateTime.tryParse(json['created_at'])!,
      friend: friend,
      unreadCount: 0,
      lastMessageSenderId: json['last_message_sender_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'members_id': membersId,
      'members': members ?? [],
      'last_message': lastMessage,
      'last_message_time': lastMessageTime,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PrivateChatModel copyWith({
    List<String>? members,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageTime,
    DateTime? createdAt,
    UserModel? friend,
    int? unreadCount,
  }) {
    return PrivateChatModel(
      chatId: chatId,
      membersId: membersId,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      createdAt: createdAt ?? this.createdAt,
      friend: friend ?? this.friend,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
