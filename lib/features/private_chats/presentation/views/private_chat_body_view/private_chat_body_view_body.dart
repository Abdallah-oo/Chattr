import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/routing/router.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/message/chat_message_list.dart';
import 'package:chattr/core/widgets/message/send_message_field.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

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
  int _lastMarkedUnread = -1;

  String get _chatId => widget.chatData.chatId as String;

  @override
  void initState() {
    super.initState();
    AppRouter.activeChatId = _chatId;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FetchPrivateMessagesCubit>().loadInitialMessages(
        chatId: widget.chatData.chatId!,
      );
    });
  }

  @override
  void dispose() {
    if (AppRouter.activeChatId == _chatId) {
      AppRouter.activeChatId = null;
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    if (pos.pixels >= pos.maxScrollExtent - 100 && !_isPaginating) {
      final cubit = context.read<FetchPrivateMessagesCubit>();
      if (cubit.hasMore(_chatId)) {
        _isPaginating = true;
        cubit.loadMoreMessages(_chatId).then((_) => _isPaginating = false);
      }
    }
  }

  void _handleNewMessages(FetchPrivateMessagesSuccess state) {
    final unreadCount = context
        .read<FetchPrivateMessagesCubit>()
        .getUnreadCount(_chatId);

    if (unreadCount > 0 && unreadCount != _lastMarkedUnread) {
      _lastMarkedUnread = unreadCount;
      context.read<FetchPrivateMessagesCubit>().markAllAsRead(chatId: _chatId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SendPrivateMessageCubit, SendPrivateMessageState>(
      listener: (context, state) {
        if (state is SendPrivateMessageFailure) {
          CustomSnackBar.error(context, state.errorMessage);
        }
      },
      child: BlocListener<FetchPrivateMessagesCubit, FetchPrivateMessagesState>(
        listenWhen: (_, curr) {
          if (curr is FetchPrivateMessagesLoading) return false;
          if (curr is! FetchPrivateMessagesSuccess) return false;
          return curr.chatId == widget.chatData.chatId;
        },
        listener: (context, state) {
          if (state is FetchPrivateMessagesSuccess) _handleNewMessages(state);
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
                    chatData: widget.chatData,
                    currentUser: widget.curruntUser,
                    scrollController: _scrollController,
                    reversed: true,
                  ),
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
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const Gap(5),
                                Flexible(
                                  child: CustomText(
                                    maxLines: 1,
                                    text:
                                        '"Messages in this chat are end-to-end encrypted."',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
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
                ],
              ),
            ),
            SendMessageField(
              chatData: widget.chatData,
              curruntUser: widget.curruntUser,
            ),
          ],
        ),
      ),
    );
  }
}
