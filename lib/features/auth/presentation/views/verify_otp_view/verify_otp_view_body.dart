import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/auth/presentation/cubits/reset_password_cubit/reset_password_cubit.dart';
import 'package:chattr/features/auth/presentation/views/widgets/otp_input_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class VerifyOtpViewBody extends StatefulWidget {
  const VerifyOtpViewBody({super.key});

  @override
  State<VerifyOtpViewBody> createState() => _VerifyOtpViewBodyState();
}

class _VerifyOtpViewBodyState extends State<VerifyOtpViewBody> {
  String _currentCode = '';

  void _verify(BuildContext context) {
    if (_currentCode.length < 6) {
    CustomSnackBar.error(context, "Please enter the full code");
      return;
    }
    context.read<ResetPasswordCubit>().verifyOtp(_currentCode);
  }

  @override
  Widget build(BuildContext context) {
    final email = context.read<ResetPasswordCubit>().state.email;

    return BlocListener<ResetPasswordCubit, ResetPasswordState>(
      listener: (context, state) {
        if (state.status == ResetPasswordStatus.otpVerified) {
          context.push(Routes.setNewPassword);
        } else if (state.status == ResetPasswordStatus.verifyOtpFailure) {
       CustomSnackBar.error(context, state.errorMessage ?? 'Invalid code');
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(context.screenHeight * 0.12),
              CustomText(
                text: "Verify Code",
                style: AppTextStyles.displayMedium,
              ),
              Gap(10),
              CustomText(
                text: "Enter the 6-digit code sent to $email",
                style: AppTextStyles.bodyMedium,
              ),
              Gap(30),
              OtpInputField(
                onChanged: (code) => _currentCode = code,
                onCompleted: (code) {
                  _currentCode = code;
                  _verify(context);
                },
              ),
              Gap(30),
              BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
                builder: (context, state) {
                  final isLoading =
                      state.status == ResetPasswordStatus.verifyingOtp;
                  return CustomButton(
                    onPressed: isLoading ? null : () => _verify(context),
                    raduis: 15,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomText(
                          text: "Verify",
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
    );
  }
}
