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
import 'package:messenger_clone0/features/contacts/presentation/cubits/add_to_contacts_cubit/add_to_contacts_cubit.dart';

class AddContactBottomSheet extends StatefulWidget {
  const AddContactBottomSheet({super.key}); // ← شيلنا required this.context

  @override
  State<AddContactBottomSheet> createState() => _AddContactBottomSheetState();
}

class _AddContactBottomSheetState extends State<AddContactBottomSheet> {
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
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: BlocListener<AddToContactsCubit, AddToContactsState>(
        listener: (context, state) {
          if (state is AddToContactsFailure) {
            CustomSnackBar.error(
              context,
              state.errorMessage,
            ); // ← context مش widget.context
            context.pop();
          }
          if (state is AddToContactsSuccess) {
            CustomSnackBar.success(
              context,
              "user added to contacts successfully",
            );
            context.pop();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Gap(9),

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
                  Gap(10),
                  Row(
                    children: [
                      CustomText(
                        text: "Add contact",
                        style: AppTextStyles.headlineSmall,
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.qr_code_scanner,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const Gap(15),
                  CustomTextField(
                    controller: _emailController,
                    hint: "Email",
                    borderColor: AppColors.border,
                    textStyle: AppTextStyles.bodySmall,
                    validation: AuthValidation.email ,
                  ),
                  const Gap(10),
                  _AddContactButton(
                    formKey: _formKey,
                    emailController: _emailController,
                  ),
                  const Gap(20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddContactButton extends StatelessWidget {
  const _AddContactButton({
    required GlobalKey<FormState> formKey,
    required TextEditingController emailController,
  }) : _formKey = formKey,
       _emailController = emailController;

  final GlobalKey<FormState> _formKey;
  final TextEditingController _emailController;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddToContactsCubit, AddToContactsState>(
      buildWhen: (prev, curr) =>
          curr is AddToContactsLoading || prev is AddToContactsLoading,
      builder: (context, state) {
        final isLoading = state is AddToContactsLoading;
        return CustomButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              context.read<AddToContactsCubit>().addContact(
                _emailController.text.trim(),
              );
            }
          },
          raduis: 7,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomText(
                text: "Add To Contacts",
                style: AppTextStyles.buttonMedium,
              ),
              Gap(5),
              isLoading
                  ? CupertinoActivityIndicator(color: Colors.grey, radius: 8)
                  : SizedBox.shrink(),
            ],
          ),
        );
      },
    );
  }
}
