import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/cubits/fetch_current_user_data/fetch_current_user_data_cubit.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class Grouplist extends StatelessWidget {
  const Grouplist({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchGroupsCubit, FetchGroupsState>(
      builder: (context, state) {
        final UserModel? currentUser = context
            .select<FetchCurrentUserDataCubit, UserModel?>(
              (cubit) => cubit.currentUser,
            );

        if (currentUser == null) {
          return const SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        if (state is FetchGroupsSuccess) {
          final List<GroupModel> myGroups = state.groups;
          if (myGroups.isEmpty) {
            return const SliverFillRemaining(
              child: Center(
                child: CustomText(
                  text: '👥 No Groups yet ',
                  style: AppTextStyles.headlineMedium,
                ),
              ),
            );
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate(childCount: myGroups.length, (
              context,
              index,
            ) {
              final String? lastMessageTime =
                  myGroups[index].lastMessageTime == null
                  ? null
                  : DateFormat('jm').format(myGroups[index].lastMessageTime!);
              String? senderName;

              if (myGroups[index].lastMessage != null) {
                senderName = myGroups[index].getLastMessageSenderName(
                  currentUserId: currentUser.id!,
                  lastMessageSenderId: myGroups[index].lastMessageSenderId!,
                );
              }

              return Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      final groupData = GroupChatParams(
                        groupData: myGroups[index],
                        currentUser: currentUser,
                        memberData: myGroups[index].members!,
                      );
                      context.push(Routes.groupMessages, extra: groupData);
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _GroupProfileImage(group: myGroups[index]),
                            Gap(20),
                            _GroupNameAndLastMessage(
                              group: myGroups[index],
                              senderName: senderName,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _UnreadCount(
                    group: myGroups[index],
                    lastMessageTime: lastMessageTime,
                  ),
                ],
              );
            }),
          );
        } else if (state is FetchGroupsFailure) {
          return SliverFillRemaining(child: Text(state.errorMessage));
        } else {
          return SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
      },
    );
  }
}

class _UnreadCount extends StatelessWidget {
  const _UnreadCount({required this.group, required this.lastMessageTime});

  final GroupModel group;
  final String? lastMessageTime;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 10,
      child: group.unreadCount > 0
          ? CircleAvatar(
              radius: 10,
              backgroundColor: AppColors.primary,
              child: CustomText(
                text: group.unreadCount.toString(),
                style: AppTextStyles.bodySmall,
              ),
            )
          : lastMessageTime != null
          ? CustomText(
              text: lastMessageTime!,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 9),
            )
          : SizedBox.fromSize(),
    );
  }
}

class _GroupNameAndLastMessage extends StatelessWidget {
  const _GroupNameAndLastMessage({
    required this.group,
    required this.senderName,
  });

  final GroupModel group;
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(text: group.name ?? '', style: AppTextStyles.bodyMedium),
          CustomText(
            minFontSize: 12,
            style: AppTextStyles.bodySmall,
            text: group.lastMessage == null
                ? 'Start the conversation 💬'
                : "$senderName: ${group.lastMessage}",
          ),
        ],
      ),
    );
  }
}

class _GroupProfileImage extends StatelessWidget {
  const _GroupProfileImage({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      child: ClipOval(
        child: CachedNetworkImage(
          height: 100,
          width: 100,
          fit: BoxFit.fill,
          imageUrl:
              group.image ??
              'https://static.thenounproject.com/png/1856610-200.png',
          placeholder: (context, url) =>
              CupertinoActivityIndicator(color: Colors.white54, radius: 9),
          errorWidget: (context, url, error) => const Icon(
            Icons.image_not_supported_outlined,
            color: Colors.red,
            size: 40,
          ),
        ),
      ),
    );
  }
}
