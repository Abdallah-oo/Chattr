import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger_clone0/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:messenger_clone0/core/helpers/snack_bar.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/utils/validators/auth_validation.dart';
import 'package:messenger_clone0/core/widgets/custom_appbar.dart';
import 'package:messenger_clone0/core/widgets/custom_button.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/core/widgets/image/ui/pick_image.dart';
import 'package:messenger_clone0/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:messenger_clone0/features/group_chats/presentation/cubits/create_group_cubit/create_group_cubit.dart';
import 'package:messenger_clone0/features/group_chats/presentation/cubits/select_group_members_cubit/select_group_members_cubit.dart';
import 'package:messenger_clone0/features/group_chats/presentation/views/groups_view/widgets/group_members_list.dart';

class CreatGroup extends StatefulWidget {
  const CreatGroup({super.key, required this.contactsCubit});
  final FetchContactsCubit contactsCubit;

  @override
  State<CreatGroup> createState() => _CreatGroupState();
}

class _CreatGroupState extends State<CreatGroup> {
  late TextEditingController groupNameController;
  final _formKey = GlobalKey<FormState>();
  final ValueNotifier<bool> isFormValid = ValueNotifier(false);

  @override
  void initState() {
    groupNameController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: BlocProvider.value(
        value: widget.contactsCubit,
        child: Scaffold(
          appBar: CustomAppBar(
            title: "Create Group",
            actions: [],
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
            ),
          ),

          body: BlocListener<CreateGroupCubit, CreateGroupState>(
            listener: (context, state) {
              if (state is CreateGroupSuccess) {
                context.pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                   CustomSnackBar.success(context, "groupCreatedSuccessfully");
                });
                
              }
              if (state is CreateGroupfailure) {
                CustomSnackBar.error(context, state.errorMessage);
              }
            },
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Gap(40),
                            CustomText(
                              text: "Select Group Image",
                              style: AppTextStyles.headlineSmall,
                            ),
                            Gap(10),
                            PickImageWidget(
                              isProfile: true,
                              defaultImageUrl:
                                  'https://thumbs.dreamstime.com/b/linear-group-icon-customer-service-outline-collection-thin-line-vector-isolated-white-background-138644548.jpg?w=768',
                            ),
                            Gap(20),
                            _GroupDataTextField(
                              controller: groupNameController,
                              hint: "groupname :",
                              onChanged: (v) => isFormValid.value =
                                  _formKey.currentState?.validate() ?? false,
                            ),
                            Gap(40),
                            CustomText(
                              text: "Select Group members",
                              style: AppTextStyles.headlineSmall,
                            ),
                            Gap(10),
                            BlocBuilder<FetchContactsCubit, FetchContactsState>(
                              builder: (context, state) {
                                if (state is FetchContactsSuccess) {
                                  final myContacts = state.contacts;
                                  return GroupMembersList(
                                    myContacts: myContacts,
                                  );
                                } else if (state is FetchContactsFailure) {
                                  return Center(
                                    child: Text(state.errorMessage),
                                  );
                                } else {
                                  return Center(
                                    child: CupertinoActivityIndicator(
                                      radius: 12,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _CreatGroupButton(
                  formKey: _formKey,
                  isFormValid: isFormValid,
                  groupNameController: groupNameController,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatGroupButton extends StatelessWidget {
  const _CreatGroupButton({
    required this.formKey,
    required this.isFormValid,
    required this.groupNameController,
  });
  final GlobalKey<FormState> formKey;
  final ValueNotifier<bool> isFormValid;
  final TextEditingController groupNameController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: ValueListenableBuilder<bool>(
        valueListenable: isFormValid,
        builder: (context, value, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            child: BlocBuilder<PickImageCubit, PickImageState>(
              buildWhen: (prev, curr) =>
                  curr is PickImageSuccess || prev is PickImageSuccess,
              builder: (context, state) {
                final imagePath = state is PickImageSuccess
                    ? state.imageFile
                    : null;
                return BlocBuilder<
                  SelectGroupMembersCubit,
                  SelectGroupMembersState
                >(
                  builder: (context, state) {
                    final selectedMembers = context
                        .read<SelectGroupMembersCubit>()
                        .selectedMembers;
                    return BlocBuilder<CreateGroupCubit, CreateGroupState>(
                      buildWhen: (prev, curr) =>
                          curr is CreateGroupLoading ||
                          prev is CreateGroupLoading,
                      builder: (context, state) {
                        final isLoading = state is CreateGroupLoading;
                        return CustomButton(
                          onPressed: value && imagePath != null
                              ? () {
                                  context.read<CreateGroupCubit>().creatGroup(
                                    groupImageFile: imagePath,
                                    groupName: groupNameController.text.trim(),
                                    members: selectedMembers,
                                  );
                                }
                              : null,
                          color:
                              value &&
                                  imagePath != null &&
                                  selectedMembers.isNotEmpty
                              ? null
                              : AppColors.inputBorder,
                          padding: EdgeInsets.symmetric(vertical: 10),
                          raduis: 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomText(
                                text: "Creat Group",
                                style: AppTextStyles.headlineSmall,
                              ),
                              Gap(5),
                              isLoading
                                  ? CupertinoActivityIndicator(
                                      color: Colors.grey,
                                      radius: 9,
                                    )
                                  : SizedBox.shrink(),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _GroupDataTextField extends StatelessWidget {
  const _GroupDataTextField({
    required this.hint,

    this.controller,
    this.onChanged,
  });
  final String hint;

  final TextEditingController? controller;
  final Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: AuthValidation.required,
      onChanged: onChanged,
      controller: controller,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintStyle: TextStyle(color: AppColors.textHint),
        hintText: hint,
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.inputBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border, width: 1.2),
        ),
      ),
    );
  }
}
