import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/auth/presentation/cubits/signup-verification_cubit/signup_verification_cubit.dart';
import 'package:chattr/features/auth/presentation/views/widgets/otp_input_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class VerifySignupOtpViewBody extends StatefulWidget {
  const VerifySignupOtpViewBody({super.key});

  @override
  State<VerifySignupOtpViewBody> createState() =>
      _VerifySignupOtpViewBodyState();
}

class _VerifySignupOtpViewBodyState extends State<VerifySignupOtpViewBody> {
  String _currentCode = '';

  void _verify(BuildContext context) {
    if (_currentCode.length < 6) {
      CustomSnackBar.error(context, "Please enter the full code");
      return;
    }
    context.read<SignupVerificationCubit>().verifyOtp(_currentCode);
  }

  @override
  Widget build(BuildContext context) {
    final email = context.read<SignupVerificationCubit>().state.email;

    return BlocListener<SignupVerificationCubit, SignupVerificationState>(
      listener: (context, state) {
        if (state.status == SignupVerificationStatus.verified) {
          CustomSnackBar.success(
            context,
            'Email verified successfully , you can now login',
          );
          context.pop();
        } else if (state.status == SignupVerificationStatus.verifyFailure) {
          CustomSnackBar.error(context, state.errorMessage ?? 'Invalid code');
        } else if (state.status == SignupVerificationStatus.resent) {
          CustomSnackBar.success(context, 'Code resent');
        } else if (state.status == SignupVerificationStatus.resendFailure) {
          CustomSnackBar.error(
            context,
            state.errorMessage ?? 'Failed to resend',
          );
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
                text: "Confirm Your Email",
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
              Gap(20),
              BlocBuilder<SignupVerificationCubit, SignupVerificationState>(
                builder: (context, state) {
                  final isResending =
                      state.status == SignupVerificationStatus.resending;
                  final canResend = state.remainingSeconds == 0 && !isResending;

                  return Center(
                    child: TextButton(
                      onPressed: canResend
                          ? () => context
                                .read<SignupVerificationCubit>()
                                .resendOtp()
                          : null,
                      child: CustomText(
                        text: isResending
                            ? "Resending..."
                            : canResend
                            ? "Resend Code"
                            : "Resend in ${state.remainingSeconds}s",
                        style: AppTextStyles.labelLarge,
                      ),
                    ),
                  );
                },
              ),
              Gap(20),
              BlocBuilder<SignupVerificationCubit, SignupVerificationState>(
                builder: (context, state) {
                  final isLoading =
                      state.status == SignupVerificationStatus.verifying;
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
