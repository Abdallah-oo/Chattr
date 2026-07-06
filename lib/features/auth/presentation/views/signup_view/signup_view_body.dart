import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/utils/validators/auth_validation.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/core/widgets/image/ui/pick_image.dart';
import 'package:chattr/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SignupViewBody extends StatefulWidget {
  const SignupViewBody({super.key});

  @override
  State<SignupViewBody> createState() => _SignupViewBodyState();
}

class _SignupViewBodyState extends State<SignupViewBody> {
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier(false);
  final formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  @override
  void initState() {
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
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

              CustomText(text: "SignUp", style: AppTextStyles.displayMedium),
              Gap(20),
              PickImageWidget(isProfile: true),
              Gap(20),
              CustomTextField(
                keyboardType: TextInputType.name,

                prefixIcon: const Icon(CupertinoIcons.person),
                hint: "Name",
                controller: _nameController,
                validation: AuthValidation.required,
              ),
              Gap(10),
              CustomTextField(
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(CupertinoIcons.mail),
                hint: "Email",
                controller: _emailController,
                validation: AuthValidation.email,
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
              _SignupButton(
                nameController: _nameController,
                emailController: _emailController,
                passwordController: _passwordController,
                formKey: formKey,
              ),
              Gap(10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    context.pop();
                  },
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "Already have An Account ? ",
                          style: AppTextStyles.bodySmall, // النص العادي
                        ),
                        TextSpan(
                          text: "Login",
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
class _SignupButton extends StatelessWidget {
  const _SignupButton({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.nameController,
  });
  final TextEditingController emailController;
  final TextEditingController nameController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;

  void _signup(BuildContext context) {
    final imageFile = context.read<PickImageCubit>().imageFile;
    if (imageFile == null) {
      CustomSnackBar.warning(context, 'Please select a profile picture');
      return;
    }
    if (formKey.currentState!.validate()) {
      context.read<AuthCubit>().onTapSignUpBut(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        image: imageFile,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isLoading =
            state.status == AuthStatus.loading &&
            state.action == AuthAction.signup;
        return CustomButton(
          onPressed: isLoading ? null : () => _signup(context),

          raduis: 15,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomText(text: "Sign Up", style: AppTextStyles.buttonLarge),
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
