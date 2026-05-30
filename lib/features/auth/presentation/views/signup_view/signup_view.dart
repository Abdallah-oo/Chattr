import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:chattr/features/auth/presentation/views/signup_view/signup_view_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SignupView extends StatelessWidget {
  const SignupView({super.key});

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
            CustomSnackBar.success(
              context,
              'Successfully Registered , you can login now',
            );
            context.pop();
          }
        },
        child: Scaffold(body: SignupViewBody()),
      ),
    );
  }
}
