import 'package:chattr/core/widgets/message/chat_message_list.dart';
import 'package:chattr/core/widgets/message/send_message_field.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class GroupMessageViewBody extends StatefulWidget {
  const GroupMessageViewBody({
    super.key,
    required this.groupData,
    required this.currentUser,
  });

  final GroupModel groupData;
  final UserModel currentUser;

  @override
  State<GroupMessageViewBody> createState() => _GroupMessageViewBodyState();
}

class _GroupMessageViewBodyState extends State<GroupMessageViewBody> {
  late ScrollController lastMessageScroll;

  @override
  void initState() {
    super.initState();
    lastMessageScroll = ScrollController();

    final cubit = context.read<FetchGroupMessagesCubit>();
    cubit.loadInitialMessages(groupId: widget.groupData.id!).then((_) {
      cubit.markGroupAsRead(groupId: widget.groupData.id!);
    });
  }

  @override
  void dispose() {
    lastMessageScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: lastMessageScroll,
            slivers: [
              SliverToBoxAdapter(
                child: Gap(20),
              ),
              ChatMessagesList(
                currentUser: widget.currentUser,
                scrollController: lastMessageScroll,
                chatData: widget.groupData,
              ),
            ],
          ),
        ),
        SendMessageField(
          chatData: widget.groupData,
          curruntUser: widget.currentUser,
        ),
      ],
    );
  }
}
