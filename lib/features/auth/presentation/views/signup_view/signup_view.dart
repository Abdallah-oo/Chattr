import 'package:flutter/material.dart';
import 'package:messenger_clone0/features/auth/presentation/views/signup_view/signup_view_body.dart';

class SignupView extends StatelessWidget {
  const SignupView({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(body: SignupViewBody()),
    );
  }
}
