import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_constants.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/messenger_clone_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase
  WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  Hive.registerAdapter(UserModelAdapter());
  await Hive.openBox<UserModel>(HiveService.userBoxName);


  runApp(const MessengerCloneApp());
}


