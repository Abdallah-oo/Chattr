import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger_clone0/core/helpers/snack_bar.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/utils/validators/auth_validation.dart';
import 'package:messenger_clone0/core/widgets/custom_button.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/core/widgets/custom_text_field.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/add_friend_cubit/add_friend_cubit.dart';

class AddFriendBottomSheet extends StatefulWidget {
  const AddFriendBottomSheet({super.key});

  @override
  State<AddFriendBottomSheet> createState() => _AddFriendBottomSheetState();
}

class _AddFriendBottomSheetState extends State<AddFriendBottomSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<AddFriendCubit, AddFriendState>(
      listener: (context, state) {
        if (state is AddFriendFailure) {
          CustomSnackBar.error(context, state.errMessage);
          context.pop();
        }
        if (state is AddFriendSuccess) {
          CustomSnackBar.success(context, 'Your friend was added successfully');
        }
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Gap(7),
                Center(
                  child: Container(
                    height: 5,
                    width: 50,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    CustomText(
                      text: 'Add Friend Email',
                      style: AppTextStyles.headlineSmall,
                    ),
                    const Spacer(),
                    const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                  ],
                ),
                const Gap(15),
                CustomTextField(
                  controller: _emailController,
                  hint: 'Email',
                  borderColor: AppColors.inputBorder,
                  textStyle: AppTextStyles.bodySmall,
                  validation: AuthValidation.email ,
                ),
                const Gap(10),
                _AddButton(
                  formKey: _formKey,
                  emailController: _emailController,
                ),
                const Gap(20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required GlobalKey<FormState> formKey,
    required TextEditingController emailController,
  }) : _formKey = formKey,
       _emailController = emailController;

  final GlobalKey<FormState> _formKey;
  final TextEditingController _emailController;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddFriendCubit, AddFriendState>(
      buildWhen: (prev, curr) =>
          curr is AddFriendLoading || prev is AddFriendLoading,
      builder: (context, state) {
        final isLoading = state is AddFriendLoading;
        return CustomButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              context.read<AddFriendCubit>().addFriend(
                email: _emailController.text.trim(),
              );
            }
          },
          raduis: 7,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CustomText(text: 'Add Friend'),
              const Gap(5),
              if (isLoading)
                const CupertinoActivityIndicator(color: Colors.grey, radius: 8),
            ],
          ),
        );
      },
    );
  }
}
