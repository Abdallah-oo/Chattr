import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:messenger_clone0/core/helpers/snack_bar.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_auth_services.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/utils/di/get_it.dart';
import 'package:messenger_clone0/core/utils/extensions/responsive.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/core/widgets/message/chat_message_list.dart';
import 'package:messenger_clone0/core/widgets/message/send_message_field.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';

class PrivateChatBodyViewBody extends StatefulWidget {
  const PrivateChatBodyViewBody({
    super.key,
    required this.chatData,
    required this.curruntUser,
  });

  final dynamic chatData;
  final UserModel curruntUser;

  @override
  State<PrivateChatBodyViewBody> createState() =>
      _PrivateChatBodyViewBodyState();
}

class _PrivateChatBodyViewBodyState extends State<PrivateChatBodyViewBody> {
  final ScrollController _scrollController = ScrollController();
  bool _isPaginating = false;
  bool _userScrolledUp = false;
  bool _initialScrollDone = false;
  int _prevMessageCount = 0;

  // آخر عدد unread اتعملت له markAllAsRead — عشان مش نكررها من غير سبب
  int _lastMarkedUnread = -1;

  String get _chatId => widget.chatData.chatId as String;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;

    if (pos.pixels <= 100 && !_isPaginating) {
      final cubit = context.read<FetchPrivateMessagesCubit>();
      if (cubit.hasMore(_chatId)) {
        _isPaginating = true;
        cubit.loadMoreMessages(_chatId).then((_) => _isPaginating = false);
      }
    }

    _userScrolledUp = pos.pixels < pos.maxScrollExtent - 100;
  }

  void _scrollToBottom({bool animated = false}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;

      if (animated) {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(max);
      }
    });
  }

  void _handleNewMessages(FetchPrivateMessagesSuccess state) {
    final messages = state.messages;

    // markAllAsRead بس لو فيه unread جديد — مش في كل rebuild
    final unreadCount = context
        .read<FetchPrivateMessagesCubit>()
        .getUnreadCount(_chatId);

    if (unreadCount > 0 && unreadCount != _lastMarkedUnread) {
      _lastMarkedUnread = unreadCount;
      context.read<FetchPrivateMessagesCubit>().markAllAsRead(chatId: _chatId);
    }

    // أول load
    if (!_initialScrollDone && messages.isNotEmpty) {
      _initialScrollDone = true;
      _prevMessageCount = messages.length;
      _scrollToBottom(animated: false);
      return;
    }

    // رسايل جديدة وصلت
    if (messages.length > _prevMessageCount) {
      _prevMessageCount = messages.length;
      if (!_userScrolledUp) _scrollToBottom(animated: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SendPrivateMessageCubit, SendPrivateMessageState>(
      listener: (context, state) {
        if (state is SendPrivateMessageSuccess) {
          _scrollToBottom(animated: true);
        } else if (state is SendPrivateMessageFailure) {
          CustomSnackBar.error(context, state.errorMessage);
        }
      },
      child: BlocListener<FetchPrivateMessagesCubit, FetchPrivateMessagesState>(
        listenWhen: (_, curr) => curr is FetchPrivateMessagesSuccess,
        listener: (context, state) {
          if (state is FetchPrivateMessagesSuccess) _handleNewMessages(state);
        },
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const Gap(40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          child: Container(
                            width: context.responsiveWidth(
                              percentage: 0.8,
                              min: context.screenWidth * 0.4,
                              max: 500,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 206, 205, 203),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock, size: 18, color: Colors.grey),
                                Gap(5),
                                Flexible(
                                  child: CustomText(
                                    maxLines: 1,
                                    text:
                                        '"Messages in this chat are end-to-end encrypted."',
                                   style: AppTextStyles.headlineSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Gap(30),
                      ],
                    ),
                  ),
                  ChatMessagesList(
                    chatData: widget.chatData,
                    currentUser: widget.curruntUser,
                    scrollController: _scrollController,
                  ),
                ],
              ),
            ),
            SendMessageField(
              auth: getIt<AuthService>(),
              chatData: widget.chatData,
              curruntUser: widget.curruntUser,
            ),
          ],
        ),
      ),
    );
  }
}
