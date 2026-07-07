import 'package:chattr/chattr_app.dart';
import 'package:chattr/core/routing/router.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/notification/notification_service.dart';
import 'package:chattr/core/services/supabase/supabase_constants.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initFirebase();
  await _initHive();
  await _initSupabase();

  setUpGetIt();
  getIt<NotificationService>().init();
   getIt<AuthRepo>().updateFCM();
   final initialLocation = _resolveInitialLocation();
   AppRouter.init(initialLocation: initialLocation);

  runApp(ChattrApp());
}
String _resolveInitialLocation() {
  try {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? Routes.root : Routes.login;
  } catch (_) {
    return Routes.login;
  }
}
Future<void> _initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> _initSupabase() async {
  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.publishKey,
  );
}

Future<void> _initHive() async {
  await Hive.initFlutter();
  _registerHiveAdapters();
  await _openHiveBoxes();
}

void _registerHiveAdapters() {
  Hive
    ..registerAdapter(UserModelAdapter())
    ..registerAdapter(PrivateChatModelAdapter())
    ..registerAdapter(PrivateMessageModelAdapter())
    ..registerAdapter(PrivateMessageStatusAdapter())
    ..registerAdapter(PrivateMessageTypeAdapter())
    ..registerAdapter(GroupMessageModelAdapter())
    ..registerAdapter(GroupMessageStatusAdapter())
    ..registerAdapter(GroupMessageTypeAdapter())
    ..registerAdapter(GroupModelAdapter())
    ..registerAdapter(UserInGroupAdapter());
}

Future<void> _openHiveBoxes() async {
  await Future.wait([
    Hive.openBox<UserModel>(HiveService.userBoxName),
    Hive.openBox<PrivateChatModel>(HiveService.privateChatsBoxName),
    Hive.openBox<PrivateMessageModel>(HiveService.privateMessageBoxName),
    Hive.openBox<GroupModel>(HiveService.groupsBoxName),
    Hive.openBox<GroupMessageModel>(HiveService.groupsMessagesBoxName),
  ]);
}
