

import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';

class UsersCache {
  static final Map<String, UserModel> _cache = {};

  static bool contains(String id) => _cache.containsKey(id);

  static UserModel? getUser(String id) {
    return _cache[id];
  }

  static Future<UserModel?> getUserSmart(String id) async {
    // 1️⃣ دور في الذاكرة
    if (_cache.containsKey(id)) return _cache[id];

    // 2️⃣ دور في Hive
    final user = await HiveService.getUser(id);
    if (user != null) {
      _cache[id] = user;
      return user;
    }

    // 3️⃣ غير موجود
    return null;
  }

  static void addUser(UserModel user) {
    if (user.id != null) {
      _cache[user.id!] = user;
    }
  }

  static void addUsers(List<UserModel> users) {
    for (var u in users) {
      addUser(u);
    }
  }

  static void clear() {
    _cache.clear();
  }
}
