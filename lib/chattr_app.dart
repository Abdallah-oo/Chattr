import 'package:chattr/core/routing/router.dart';
import 'package:flutter/material.dart';

class ChattrApp extends StatelessWidget {
  const ChattrApp({super.key});

  // This widget is the root of your application.
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


