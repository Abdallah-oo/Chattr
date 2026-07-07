import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/features/auth/presentation/cubits/auto_login_cubit/auto_login_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<AutoLoginCubit, AutoLoginState>(
      listener: (context, state) {
        if (state is AutoLoginSuccess) {
          context.pushReplacement(Routes.root);
        } else if (state is AutoLoginFailure) {
          context.pushReplacement(Routes.login);
        }
      },
      child: Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        )
      ),
    );
  }
}
