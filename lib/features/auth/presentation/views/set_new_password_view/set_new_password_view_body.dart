import 'package:chattr/core/helpers/snack_bar.dart';
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

class SetNewPasswordViewBody extends StatefulWidget {
  const SetNewPasswordViewBody({super.key});

  @override
  State<SetNewPasswordViewBody> createState() => _SetNewPasswordViewBodyState();
}

class _SetNewPasswordViewBodyState extends State<SetNewPasswordViewBody> {
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier(false);
  final ValueNotifier<bool> _isConfirmVisible = ValueNotifier(false);
  final formKey = GlobalKey<FormState>();
  late TextEditingController _passwordController;
  late TextEditingController _confirmController;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateConfirm(String? value) {
    if (value != _passwordController.text) {
      return "Passwords don't match";
    }
    return null;
  }

  void _submit(BuildContext context) {
    if (formKey.currentState!.validate()) {
      context.read<ResetPasswordCubit>().updatePassword(
        _passwordController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ResetPasswordCubit, ResetPasswordState>(
      listener: (context, state) {
        if (state.status == ResetPasswordStatus.passwordUpdated) {
          context.pop();
        } else if (state.status == ResetPasswordStatus.updatePasswordFailure) {
         CustomSnackBar.error(context, state.errorMessage ?? 'Something went wrong');
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
                  text: "Set New Password",
                  style: AppTextStyles.displayMedium,
                ),
                Gap(20),
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
                      hint: 'New Password',
                      validation: AuthValidation.password,
                    );
                  },
                ),
                Gap(10),
                ValueListenableBuilder<bool>(
                  valueListenable: _isConfirmVisible,
                  builder: (context, isVisible, _) {
                    return CustomTextField(
                      controller: _confirmController,
                      keyboardType: TextInputType.text,
                      prefixIcon: const Icon(CupertinoIcons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => _isConfirmVisible.value = !isVisible,
                      ),
                      secure: !isVisible,
                      hint: 'Confirm Password',
                      validation: _validateConfirm,
                    );
                  },
                ),
                Gap(30),
                BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
                  builder: (context, state) {
                    final isLoading =
                        state.status == ResetPasswordStatus.updatingPassword;
                    return CustomButton(
                      onPressed: isLoading ? null : () => _submit(context),
                      raduis: 15,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomText(
                            text: "Update Password",
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
