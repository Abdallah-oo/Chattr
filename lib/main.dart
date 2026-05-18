import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_constants.dart';
import 'package:messenger_clone0/core/utils/di/get_it.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_message_model.dart';
import 'package:messenger_clone0/messenger_clone_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
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

  await Hive.openBox<UserModel>(HiveService.userBoxName);
  await Hive.openBox<PrivateChatModel>(HiveService.privateChatsBoxName);
  await Hive.openBox<PrivateMessageModel>(HiveService.privateMessageBoxName);

  runApp(const MessengerCloneApp());
}
