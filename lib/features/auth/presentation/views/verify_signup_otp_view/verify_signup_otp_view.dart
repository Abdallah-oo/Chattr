

import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/features/auth/presentation/views/verify_signup_otp_view/verify_signup_otp_view_body.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VerifySignupOtpView extends StatelessWidget {
  const VerifySignupOtpView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      backgroundColor: AppColors.background,
      body: const SafeArea(child: VerifySignupOtpViewBody()),
    );
  }
}
