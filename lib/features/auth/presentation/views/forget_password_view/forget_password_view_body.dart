import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/utils/validators/auth_validation.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/auth/presentation/cubits/reset_password_cubit/reset_password_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordViewBody extends StatefulWidget {
  const ForgotPasswordViewBody({super.key});

  @override
  State<ForgotPasswordViewBody> createState() => _ForgotPasswordViewBodyState();
}

class _ForgotPasswordViewBodyState extends State<ForgotPasswordViewBody> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendOtp(BuildContext context) {
    if (formKey.currentState!.validate()) {
      context.read<ResetPasswordCubit>().sendOtp(_emailController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ResetPasswordCubit, ResetPasswordState>(
      listener: (context, state) {
        if (state.status == ResetPasswordStatus.otpSent) {
          context.pushReplacement(Routes.verifyOtp);
        } else if (state.status == ResetPasswordStatus.sendOtpFailure) {
          CustomSnackBar.error(context, 'Something went wrong');
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Gap(context.screenHeight * 0.12),
                CustomText(
                  text: "Forgot Password",
                  style: AppTextStyles.displayMedium,
                ),
                Gap(10),
                CustomText(
                  text:
                      "Enter your email and we'll send you a code to reset your password",
                  style: AppTextStyles.bodyMedium,
                ),
                Gap(30),
                CustomTextField(
                  hint: "Email",
                  controller: _emailController,
                  validation: AuthValidation.email,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(CupertinoIcons.mail),
                ),
                Gap(30),
                BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
                  builder: (context, state) {
                    final isLoading =
                        state.status == ResetPasswordStatus.sendingOtp;
                    return CustomButton(
                      onPressed: isLoading ? null : () => _sendOtp(context),
                      raduis: 15,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomText(
                            text: "Send Code",
                            style: AppTextStyles.buttonLarge,
                          ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
