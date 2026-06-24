import 'package:chattr/core/services/hive/hive_type_ids.dart';
import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: HiveTypeIds.users) // رقم فريد
class UserModel {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String? name;

  @HiveField(2)
  final String? email;

  @HiveField(3)
  final String? image;

  @HiveField(4)
  final String? about;

  @HiveField(5)
  final DateTime? createdAt;

  @HiveField(6)
  final DateTime? lastSeen;

  @HiveField(7)
  final List<String>? myContacts;

  @HiveField(8)
  final bool? isOnLine;

  @HiveField(9)
  final String? fcmToken;

  UserModel({
    required this.id,
    this.name,

    this.email,
    this.image,
    this.about,
    this.createdAt,
    this.myContacts,
    this.lastSeen,
    this.isOnLine,
    this.fcmToken
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      fcmToken: json['fcm_token'],
      id: json['id'],
      name: json['name'],
      email: json['email'],
      image: json['image'],
      about: json['about'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      lastSeen: DateTime.tryParse(json['last_seen'] ?? '') ?? DateTime.now(),
      myContacts: (json['my_contacts'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(), // 🔹 هنا التحويل من dynamic لـ String,

      isOnLine: json['is_online'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'image': image,
      'about': about,
      'created_at': createdAt?.toIso8601String(),
      'last_seen': lastSeen?.toIso8601String(),
      'is_online': isOnLine,
      'my_contacts': myContacts ?? [],
      'fcm_token' :fcmToken
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? image,
    String? about,
    DateTime? createdAt,
    DateTime? lastSeen,
    List<String>? myContacts,
    bool? isOnLine,
    String? fcmToken
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      image: image ?? this.image,
      about: about ?? this.about,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      myContacts: myContacts ?? this.myContacts,
      isOnLine: isOnLine ?? this.isOnLine,
      fcmToken: fcmToken ?? this.fcmToken
    );
  }
}
