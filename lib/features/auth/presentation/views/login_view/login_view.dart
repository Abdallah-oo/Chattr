import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger_clone0/core/helpers/snack_bar.dart';
import 'package:messenger_clone0/core/routing/routes.dart';
import 'package:messenger_clone0/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:messenger_clone0/features/auth/presentation/views/login_view/login_view_body.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
           if (state.status == AuthStatus.failure) {
            CustomSnackBar.error(context, state.errorMessage ?? '');
          }
          if (state.status == AuthStatus.success) {
            context.pushReplacement(Routes.root);
            CustomSnackBar.success(context, 'Login Successfully');
          }
        },
        child: Scaffold(body: LoginViewBody()),
      ),
    );
  }
}
