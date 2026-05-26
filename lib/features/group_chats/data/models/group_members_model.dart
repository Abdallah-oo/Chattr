class GroupMemberModel {
  final String groupId;
  final String userId;
  final DateTime? lastReadAt;
  final bool isAdmin;

  GroupMemberModel({
    required this.groupId,
    required this.userId,
    this.lastReadAt,
    this.isAdmin = false,
  });
  factory GroupMemberModel.fromJson(Map<String, dynamic> json) =>
      GroupMemberModel(
        groupId: json['group_id'],
        userId: json['user_id'],
        isAdmin: json['is_admin'],
        lastReadAt: json['last_read_at'] != null
            ? DateTime.parse(json['last_read_at'])
            : null,
      );

  Map<String, dynamic> toJson() => {
    "group_id": groupId,
    "user_id": userId,
    "is_admin": isAdmin,
  };
}
