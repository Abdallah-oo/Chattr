import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_constants.dart';
import 'package:messenger_clone0/core/utils/di/get_it.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/group_chats/data/models/group_message_model.dart';
import 'package:messenger_clone0/features/group_chats/data/models/group_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_message_model.dart';
import 'package:messenger_clone0/messenger_clone_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase

  await Hive.initFlutter();
    WidgetsFlutterBinding.ensureInitialized();

  setUpGetIt();
  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  Hive.registerAdapter(UserModelAdapter());
  Hive.registerAdapter(PrivateChatModelAdapter());
  Hive.registerAdapter(PrivateMessageModelAdapter());
  Hive.registerAdapter(PrivateMessageStatusAdapter());
  Hive.registerAdapter(PrivateMessageTypeAdapter());
  Hive.registerAdapter(GroupMessageModelAdapter());
  Hive.registerAdapter(GroupMessageStatusAdapter());
  Hive.registerAdapter(GroupMessageTypeAdapter());
  Hive.registerAdapter(GroupModelAdapter());
  Hive.registerAdapter(UserInGroupAdapter());

  await Hive.openBox<UserModel>(HiveService.userBoxName);
  await Hive.openBox<PrivateChatModel>(HiveService.privateChatsBoxName);
  await Hive.openBox<PrivateMessageModel>(HiveService.privateMessageBoxName);
  await Hive.openBox<GroupModel>(HiveService.groupsBoxName);
  await Hive.openBox<GroupMessageModel>(HiveService.groupsMessagesBoxName);

  runApp(const MessengerCloneApp());
}
