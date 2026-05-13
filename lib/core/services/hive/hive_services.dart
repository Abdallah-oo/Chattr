import 'package:hive/hive.dart';
import 'package:messenger_clone0/core/cache/users_cache.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';


class HiveService {
  static const String userBoxName = 'users';
  static const String privateChatsBoxName = 'privateChats';
  static const String privateMessageBoxName = 'privateMessages';
  static const String groupsBoxName = 'groups';
  static const String groupsMessagesBoxName = 'groupMessages';

  /// ---------------- USERS ----------------
  static Future<void> saveUser(UserModel user) async {
    final box = Hive.box<UserModel>('users');
    await box.put(user.id, user);
    UsersCache.addUser(user);
  }

  static Future<UserModel?> getUser(String id) async {
    final box = Hive.box<UserModel>('users');
    return box.get(id);
  }

  static Future<void> replaceUsers(List<UserModel> users) async {
    final box = Hive.box<UserModel>(userBoxName);
    await box.clear();
    for (var u in users) {
      await box.put(u.id, u);
      UsersCache.addUser(u);
    }
  }

  static Future<List<UserModel>> getUsers() async {
    final box = Hive.box<UserModel>('users');
    return box.values.toList();
  }

 
}
