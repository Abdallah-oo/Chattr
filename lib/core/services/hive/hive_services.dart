import 'package:chattr/core/cache/users_cache.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:hive/hive.dart';



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

  //--------------- PRIVATE CHATS ----------------
  static Future<void> savePrivateChat(PrivateChatModel chat) async {
    final box = Hive.box<PrivateChatModel>(privateChatsBoxName);
    await box.put(chat.chatId, chat);
  }

  static Future<List<PrivateChatModel>> getPrivateChats() async {
    final box = Hive.box<PrivateChatModel>(privateChatsBoxName);
    return box.values.toList();
  }

  static Future<void> replacePrivateChats(List<PrivateChatModel> chats) async {
    final box = Hive.box<PrivateChatModel>(privateChatsBoxName);
    await box.clear();
    for (var g in chats) {
      await box.put(g.chatId, g);
    }
  }

  static Future<void> clearChats() async {
    final box = Hive.box<PrivateChatModel>(privateChatsBoxName);
    await box.clear();
  }

 //----------------Private Messages ----------------
   static Future<void> savePrivateMessage(PrivateMessageModel message) async {
    final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
    final key = message.messageId ?? message.tempId;
    await box.put(key, message);
  }

  static Future<void> deletePrivateMessage(String key) async {
    final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
    await box.delete(key);
  }

  static Future<List<PrivateMessageModel>> getPrivateMessages(
    String chatId, {
    int limit = 30,
  }) async {
    final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
    final messages = box.values.where((m) => m.chatId == chatId).toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (messages.length <= limit) return messages;
    return messages.sublist(messages.length - limit);
  }

  static Future<PrivateMessageModel?> getPrivateMessage(
    String messageId,
  ) async {
    final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
    return box.get(messageId);
  }

  static Future<void> savePrivateMessageLocalPath({
    required String messageId,
    required String localPath,
  }) async {
    final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
    final msg = box.get(messageId);

    if (msg == null) return;
    await box.put(messageId, msg.copyWith(localPath: localPath));
  }

  /// جيب الـ local path
  static Future<String?> getPrivateMessageLocalPath(String messageId) async {
    final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
    final msg = box.get(messageId);
    return msg?.localPath;
  }

 //--------------- group chats ----------------


   static Future<void> saveGroup(GroupModel group) async {
    final box = Hive.box<GroupModel>(groupsBoxName);
    await box.put(group.id, group);
  }

  static Future<List<GroupModel>> getGroups() async {
    final box = Hive.box<GroupModel>(groupsBoxName);
    return box.values.toList();
  }

  static Future<void> replaceGroups(List<GroupModel> groups) async {
    final box = Hive.box<GroupModel>(groupsBoxName);
    await box.clear();
    for (var g in groups) {
      await box.put(g.id, g);
    }
  }

  static Future<void> clearGroups() async {
    final box = Hive.box<GroupModel>(groupsBoxName);
    await box.clear();
  }

  //--------------- group messages ----------------
  static Future<void> saveGroupMessage(GroupMessageModel message) async {
    final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
    final key = message.messageId ?? message.tempId;
    await box.put(key, message);
  }

  static Future<void> deleteGroupMessage(String key) async {
    final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
    await box.delete(key);
  }

  static Future<List<GroupMessageModel>> getGroupMessages(
    String groupId, {
    int limit = 30,
  }) async {
    final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
    final messages = box.values.where((m) => m.groupId == groupId).toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (messages.length <= limit) return messages;
    return messages.sublist(messages.length - limit);
  }

  static Future<GroupMessageModel?> getGroupMessage(String messageId) async {
    final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
    return box.get(messageId);
  }

  static Future<void> saveGroupMessageLocalPath({
    required String messageId,
    required String localPath,
  }) async {
    final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
    final msg = box.get(messageId);

    if (msg == null) return;
    await box.put(messageId, msg.copyWith(localPath: localPath));
  }

  /// جيب الـ local path
  static Future<String?> getGroupMessageLocalPath(String messageId) async {
    final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
    final msg = box.get(messageId);
    return msg?.localPath;
  }

  /// ---------------- Clear All ----------------

  static Future<void> clearAll() async {
    await Hive.box<UserModel>(userBoxName).clear();
    await Hive.box<PrivateChatModel>(privateChatsBoxName).clear();
    await Hive.box<PrivateMessageModel>(privateMessageBoxName).clear();
    await Hive.box<GroupModel>(groupsBoxName).clear();
    await Hive.box<GroupMessageModel>(groupsMessagesBoxName).clear();
  }
}
