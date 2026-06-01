import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/utils/validators/auth_validation.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class LoginViewBody extends StatefulWidget {
  const LoginViewBody({super.key});

  @override
  State<LoginViewBody> createState() => _LoginViewBodyState();
}

class _LoginViewBodyState extends State<LoginViewBody> {
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier(false);
  final formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: "@gmail.com");
    _passwordController = TextEditingController(text: "123456789");
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(context.screenHeight * 0.1),
              Center(child: SvgPicture.asset("assets/svgs/logo1.svg")),
              Gap(context.screenHeight * 0.1),
              CustomText(text: "Login", style: AppTextStyles.displayMedium),
              Gap(20),
              CustomTextField(
                hint: "Email",
                controller: _emailController,
                validation: AuthValidation.email,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(CupertinoIcons.mail),
              ),
              Gap(10),
              ValueListenableBuilder<bool>(
                valueListenable: _isPasswordVisible,
                builder: (context, isVisible, _) {
                  return CustomTextField(
                    controller: _passwordController,
                    keyboardType: TextInputType.text,
                    prefixIcon: const Icon(CupertinoIcons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => _isPasswordVisible.value = !isVisible,
                    ),
                    secure: !isVisible,
                    hint: 'password',
                    validation: AuthValidation.password,
                  );
                },
              ),
              Gap(30),
              _LoginButton(
                formKey: formKey,
                emailController: _emailController,
                passwordController: _passwordController,
              ),
              Gap(10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    context.push(Routes.signup);
                  },
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "Don't have an account? ",
                          style: AppTextStyles.bodySmall, // النص العادي
                        ),
                        TextSpan(
                          text: "Sign Up",
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                          ), // الجزء القابل للضغط
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//login button
class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
  });
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;

  void _login(BuildContext context) {
    if (formKey.currentState!.validate()) {
      context.read<AuthCubit>().onTapLoginBut(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isLoading =
            state.status == AuthStatus.loading &&
            state.action == AuthAction.login;
        return CustomButton(
          onPressed: isLoading ? null : () => _login(context),

          raduis: 15,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomText(text: "Login", style: AppTextStyles.buttonLarge),
              Gap(10),
              if (isLoading) ...[
                const Gap(11),
                CupertinoActivityIndicator(
                  animating: true,
                  color: Colors.white,
                  radius: 10,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
