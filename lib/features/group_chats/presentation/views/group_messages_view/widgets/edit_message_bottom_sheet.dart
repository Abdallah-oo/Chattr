import 'package:chattr/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class EditGroupMessageButtomSheet extends StatefulWidget {
  const EditGroupMessageButtomSheet({
    super.key,
    required this.message,
    required this.groupId,
  });
  final String message;
  final String groupId;

  @override
  EditGroupMessageButtomSheetState createState() =>
      EditGroupMessageButtomSheetState();
}

class EditGroupMessageButtomSheetState
    extends State<EditGroupMessageButtomSheet> {
  late TextEditingController controller;
  void _editmessage() {
    final List<GroupMessageModel> selected = context
        .read<SelectMessagesCubit>()
        .selectedMessages
        .cast<GroupMessageModel>();
    context.read<FetchGroupMessagesCubit>().editMessageGroup(
      groupId: widget.groupId,
      message: selected[0],
      content: controller.text.trim(),
    );
    context.read<SelectMessagesCubit>().clearSelection();
  }

  @override
  void initState() {
    controller = TextEditingController(text: widget.message);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // علشان الكيبورد
        left: 16,
        right: 16,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomText(
              text: "Edit Message",
              style: AppTextStyles.headlineSmall,
            ),
            Gap(5),
            CustomTextField(
              hint: "",
              controller: controller,
              maxLines: 4,
              validation: (v) {
                return null;
              },
            ),
            Gap(20),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final bool isChanged =
                    value.text.trim() != widget.message &&
                    value.text.trim().isNotEmpty;
                return CustomButton(
                  onPressed: isChanged
                      ? () {
                          _editmessage();
                          context.pop();
                        }
                      : null,
                  color: isChanged ? AppColors.primary : AppColors.inputBorder,
                  raduis: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [CustomText( text: "SAVE",style: AppTextStyles.headlineSmall,)],
                  ),
                );
              },
            ),
            Gap(10),
          ],
        ),
      ),
    );
  }
}
