import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger_clone0/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:messenger_clone0/core/routing/router_models.dart';
import 'package:messenger_clone0/core/routing/routes.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/utils/di/get_it.dart';
import 'package:messenger_clone0/core/utils/extensions/responsive.dart';
import 'package:messenger_clone0/core/widgets/custom_appbar.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:messenger_clone0/features/group_chats/data/models/group_message_model.dart';
import 'package:messenger_clone0/features/group_chats/data/repos/send_group_message_repo/send_group_message_repo.dart';
import 'package:messenger_clone0/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:messenger_clone0/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:messenger_clone0/features/group_chats/presentation/cubits/send_group_message_cubit/send_group_message_cubit.dart';
import 'package:messenger_clone0/features/group_chats/presentation/views/group_messages_view/views/group_messages_view_body.dart';
import 'package:messenger_clone0/features/group_chats/presentation/views/group_messages_view/widgets/edit_message_bottom_sheet.dart';

class GroupMessagesView extends StatelessWidget {
  const GroupMessagesView({super.key, required this.groupData});
  final GroupChatParams groupData;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<FetchContactsCubit>()),
        BlocProvider.value(value: getIt<FetchGroupsCubit>()),
        BlocProvider.value(value: getIt<FetchGroupMessagesCubit>()),
        BlocProvider(
          create: (context) => SendGroupMessageCubit(
            fetchCubit: getIt<FetchGroupMessagesCubit>(),
            repo: getIt<SendGroupMessageRepo>(),
          ),
        ),
      ],
      child: BlocBuilder<FetchGroupsCubit, FetchGroupsState>(
        builder: (context, state) {
          GroupChatParams updatedGroupData = groupData;
          if (state is FetchGroupsSuccess) {
            final updatedGroup = state.groups
                .where((g) => g.id == groupData.groupData.id)
                .firstOrNull;

            updatedGroupData = GroupChatParams(
              groupData: updatedGroup!,
              currentUser: groupData.currentUser,
              memberData: updatedGroup.members ?? [],
            );
            final List<String> membres = updatedGroupData.memberData
                .map((u) => u.user.name ?? '')
                .toList();
            return GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Scaffold(
                appBar: _GroupMessagesViewAppbar(
                  groupmembers: membres,
                  groupData: updatedGroupData,
                ),

                body: GroupMessageViewBody(
                  groupData: updatedGroupData.groupData,
                  currentUser: updatedGroupData.currentUser,
                ),
              ),
            );
          } else if (state is FetchGroupsFailure) {
            return Center(
              child: CustomText(
                text: state.errorMessage,
                style: AppTextStyles.headlineSmall,
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class _GroupMessagesViewAppbar extends StatelessWidget
    implements PreferredSizeWidget {
  const _GroupMessagesViewAppbar({
    required this.groupmembers,
    required this.groupData,
  });

  final List<String> groupmembers;
  final GroupChatParams groupData;

  @override
  Widget build(BuildContext context) {
    void deletemessage() {
      final selected = context
          .read<SelectMessagesCubit>()
          .selectedMessages
          .cast<GroupMessageModel>();

      context.read<FetchGroupMessagesCubit>().deleteGroupMessages(
        groupId: groupData.groupData.id!,
        messages: selected,
      );

      context.read<SelectMessagesCubit>().clearSelection();
    }

    return CustomAppBar(
      title: groupData.groupData.name ?? '',
      titleItems: [
        SizedBox(
          width: context.screenWidth * 0.5,
          child: CustomText(
            style: AppTextStyles.bodySmall,
            text: groupmembers.join(', '),
          ),
        ),
      ],
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 15),
      ),
      actions: [
        BlocBuilder<SelectMessagesCubit, SelectMessagesState>(
          builder: (context, state) {
            final List<GroupMessageModel> selectedmessages = context
                .read<SelectMessagesCubit>()
                .selectedMessages
                .cast();

            return selectedmessages.isNotEmpty
                ? Row(
                    children: [
                      selectedmessages.length == 1 &&
                              selectedmessages[0].messageType ==
                                  GroupMessageType.text
                          ? InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled:
                                      true, // مهم علشان ياخد مساحة كبيرة
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (ctx) => BlocProvider.value(
                                    value: context.read<SelectMessagesCubit>(),

                                    child: EditGroupMessageButtomSheet(
                                      groupId: groupData.groupData.id!,
                                      message: selectedmessages[0].content,
                                    ),
                                  ),
                                );
                              },
                              child: Icon(Icons.edit, size: 20),
                            )
                          : SizedBox.shrink(),

                      Gap(10),
                      context.read<SelectMessagesCubit>().containMedia()
                          ? SizedBox.shrink()
                          : InkWell(
                              onTap: () {
                                context
                                    .read<SelectMessagesCubit>()
                                    .copyMessages();
                              },
                              child: Icon(Icons.copy, size: 20),
                            ),
                      Gap(5),
                      InkWell(
                        onTap: deletemessage,
                        child: Icon(Icons.delete_outlined, size: 25),
                      ),
                      Gap(10),
                    ],
                  )
                : Padding(
                    padding: EdgeInsets.only(right: 15),
                    child: InkWell(
                      onTap: () {
                        final GroupChatParams thisGroupData = GroupChatParams(
                          currentUser: groupData.currentUser,
                          groupData: groupData.groupData,
                          memberData: groupData.memberData,
                          fetchGroupsCubit: context.read<FetchGroupsCubit>(),
                        );
                        context.push(
                          Routes.viewGroupMembers,
                          extra: thisGroupData,
                        );
                      },
                      child: Icon(CupertinoIcons.group_solid),
                    ),
                  );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
