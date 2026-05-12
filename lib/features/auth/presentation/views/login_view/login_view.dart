import 'package:flutter/material.dart';
import 'package:messenger_clone0/features/auth/presentation/views/login_view/login_view_body.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(body: LoginViewBody()),
    );
  }
}
