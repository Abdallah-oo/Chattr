import 'package:flutter/material.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_constants.dart';
import 'package:messenger_clone0/messenger_clone_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  runApp(const MessengerCloneApp());
}


