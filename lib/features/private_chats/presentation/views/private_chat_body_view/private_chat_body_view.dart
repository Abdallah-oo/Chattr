import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger_clone0/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:messenger_clone0/core/widgets/custom_appbar.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_message_model.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:messenger_clone0/features/private_chats/presentation/views/private_chat_body_view/private_chat_body_view_body.dart';
import 'package:messenger_clone0/features/private_chats/presentation/views/private_chats_view/widgets/online_status_widget.dart';

class PrivateChatBodyView extends StatefulWidget {
  const PrivateChatBodyView({
    super.key,
    required this.chatData,
    required this.user,
  });
  final dynamic chatData;
  final UserModel user;

  @override
  State<PrivateChatBodyView> createState() => _PrivateChatBodyViewState();
}

class _PrivateChatBodyViewState extends State<PrivateChatBodyView> {
  void deletemessage(List<dynamic> selected) {
    context.read<FetchPrivateMessagesCubit>().deletePrivateMessages(
      chatId: widget.chatData.chatId!,
      messages: selected.cast<PrivateMessageModel>(),
    );

    context.read<SelectMessagesCubit>().clearSelection();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FetchPrivateMessagesCubit>().loadInitialMessages(
        chatId: widget.chatData.chatId!,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: CustomAppBar(
          title: widget.chatData.friend.name ?? "",
          titleItems: [OnlineStatusWidget(chatId: widget.chatData.chatId!)],
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 15),
          ),
          actions: [
            BlocBuilder<SelectMessagesCubit, SelectMessagesState>(
              builder: (context, state) {
                final selectedmessages = context
                    .read<SelectMessagesCubit>()
                    .selectedMessages;

                return selectedmessages.isNotEmpty
                    ? Row(
                        children: [
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
                            onTap: () => deletemessage(selectedmessages),
                            child: Icon(Icons.delete_outlined, size: 25),
                          ),
                          Gap(10),
                        ],
                      )
                    : SizedBox.shrink();
              },
            ),
          ],
        ),
        body: PrivateChatBodyViewBody(
          chatData: widget.chatData,
          curruntUser: widget.user,
        ),
      ),
    );
  }
}
