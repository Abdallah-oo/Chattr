import 'package:chattr/core/routing/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class ChattrApp extends StatefulWidget {
  const ChattrApp({super.key});
 

  @override
  State<ChattrApp> createState() => _ChattrAppState();
}

class _ChattrAppState extends State<ChattrApp> {
   @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }
  @override
  Widget build(BuildContext context) {
   return MaterialApp.router(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xff121212),
      ),
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      routerConfig: AppRouter.router,
    );
  }
}


