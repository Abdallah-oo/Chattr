import 'package:hive/hive.dart';
import 'package:messenger_clone0/core/services/hive/hive_type_ids.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';


part 'group_model.g.dart';

@HiveType(typeId: HiveTypeIds.groups)
class GroupModel {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String? name;

  @HiveField(2)
  String? createdBy;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  String? image;

  @HiveField(5)
  String? lastMessage;

  @HiveField(6)
  DateTime? lastMessageTime;

  @HiveField(7)
  String? lastMessageId;

  @HiveField(8)
  int unreadCount;

  @HiveField(9)
  List<UserInGroup>? members;
  @HiveField(10)
  String? lastMessageSenderId;

  String getLastMessageSenderName({
    required String currentUserId,
    required String lastMessageSenderId,
  }) {
    if (lastMessageSenderId == currentUserId) {
      return "You";
    }

    final sender = members?.firstWhere(
      (member) => member.user.id == lastMessageSenderId,
    );

    return sender?.user.name ?? 'Unknown';
  }

  GroupModel({
    required this.name,
    this.lastMessageSenderId,
    this.members,
    this.id,
    this.unreadCount = 0,
    this.lastMessageId,
    required this.createdBy,
    required this.createdAt,
    required this.image,
    required this.lastMessage,
    required this.lastMessageTime,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'] as List? ?? [];
    final membersList = membersJson.map((m) {
      return UserInGroup(
        user: UserModel.fromJson(m['user']),
        isAdmin: m['is_admin'] ?? false,
      );
    }).toList();

    return GroupModel(
      name: json['name'],
      unreadCount: json['unreadCount'] ?? 0,
      id: json['group_id'],
      lastMessageId: json['last_message_id'],
      members: membersList,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      createdBy: json['created_by'],
      image: json['image'],
      lastMessage: json['last_message'],
      lastMessageTime:
          DateTime.tryParse(json['last_message_time'] ?? '') ?? DateTime.now(),
      lastMessageSenderId: json['last_message_sender_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'image': image,
    };
  }

  GroupModel copyWith({int? unreadCount}) {
    return GroupModel(
      id: id,
      name: name,
      unreadCount: unreadCount ?? this.unreadCount,
      createdBy: createdBy,
      createdAt: createdAt,
      image: image,
      members: members,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      lastMessageId: lastMessageId,
      lastMessageSenderId: lastMessageSenderId,
    );
  }
}

@HiveType(typeId: HiveTypeIds.usersInGroup)
class UserInGroup {
  @HiveField(0)
  UserModel user;

  @HiveField(1)
  bool isAdmin;

  UserInGroup({required this.user, required this.isAdmin});
}
