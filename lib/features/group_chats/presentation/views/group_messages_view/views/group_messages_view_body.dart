import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/widgets/message/chat_message_list.dart';
import 'package:chattr/core/widgets/message/send_message_field.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/send_group_message_cubit/send_group_message_cubit.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _isPaginating = false;
  int _lastMarkedUnread = -1;

  String get _groupId => widget.groupData.id as String;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FetchGroupMessagesCubit>().loadInitialMessages(
        groupId: _groupId,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    if (pos.pixels >= pos.maxScrollExtent - 100 && !_isPaginating) {
      final cubit = context.read<FetchGroupMessagesCubit>();
      if (cubit.hasMore(_groupId)) {
        _isPaginating = true;
        cubit.loadMoreMessages(_groupId).then((_) => _isPaginating = false);
      }
    }
  }

  void _handleNewMessages(FetchGroupMessagesSuccess state) {
    final unreadCount = widget.groupData.unreadCount;
    if (unreadCount > 0 && unreadCount != _lastMarkedUnread) {
      _lastMarkedUnread = unreadCount;
      context.read<FetchGroupMessagesCubit>().markGroupAsRead(
        groupId: _groupId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SendGroupMessageCubit, SendGroupMessageState>(
      listener: (context, state) {
        if (state is SendGroupMessageFailure) {
          CustomSnackBar.error(context, state.errorMessage);
        }
      },
      child: BlocListener<FetchGroupMessagesCubit, FetchGroupMessagesState>(
        listenWhen: (_, curr) {
          if (curr is FetchGroupMessagesLoading) return false;
          if (curr is! FetchGroupMessagesSuccess) return false;
          return curr.groupId == widget.groupData.id;
        },
        listener: (context, state) {
          if (state is FetchGroupMessagesSuccess) _handleNewMessages(state);
        },
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                
                reverse: true,
                slivers: [
                  const SliverToBoxAdapter(child: Gap(20)),
                
                  ChatMessagesList(
                    currentUser: widget.currentUser,
                    scrollController: _scrollController,
                    chatData: widget.groupData,
                    reversed: true,
                  ),
                ],
              ),
            ),
            SendMessageField(
              chatData: widget.groupData,
              curruntUser: widget.currentUser,
            ),
          ],
        ),
      ),
    );
  }
}
