import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/select_group_members_cubit/select_group_members_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GroupMembersList extends StatelessWidget {
  const GroupMembersList({super.key, required this.myContacts});

  final List<UserModel> myContacts;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: myContacts.length,
      physics: const NeverScrollableScrollPhysics(),

      itemBuilder: (context, index) {
        return BlocBuilder<SelectGroupMembersCubit, SelectGroupMembersState>(
          builder: (context, state) {
            final isSelected = context
                .read<SelectGroupMembersCubit>()
                .selectedMembers
                .contains(myContacts[index]);
            return CheckboxListTile(
              value: isSelected,

              onChanged: (value) {
                context.read<SelectGroupMembersCubit>().addMembers(
                  user: myContacts[index],
                );
              },
              activeColor: AppColors.primary,
              checkColor: Colors.white,
              checkboxShape: CircleBorder(),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              dense: true,
              visualDensity: VisualDensity.compact,
              title: CustomText(
                text: myContacts[index].name ?? '',
                style: AppTextStyles.bodySmall,
              ),
              subtitle: CustomText(
               text: myContacts[index].isOnLine == true ? 'Online' : 'Offline',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 9
                ),
              ),
              secondary:
              
              
              
               CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  myContacts[index].image ?? "https://i.pravatar.cc/150?img=3",
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        );
      },
    );
  }
}
