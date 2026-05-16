import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger_clone0/core/cache/users_cache.dart';
import 'package:messenger_clone0/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:messenger_clone0/core/routing/router_models.dart';
import 'package:messenger_clone0/core/routing/routes.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/core/widgets/message/widgets/message_content.dart';
import 'package:messenger_clone0/core/widgets/message/widgets/send_welcom_message.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_message_model.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';

class ChatMessagesList extends StatelessWidget {
  const ChatMessagesList({
    super.key,
    this.scrollController,
    required this.chatData,
    required this.currentUser,
  });

  final dynamic chatData;
  final UserModel currentUser;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final String myId = currentUser.id!;

    return  BlocBuilder<FetchPrivateMessagesCubit, FetchPrivateMessagesState>(
            builder: (context, state) {
              if (state is FetchPrivateMessagesSuccess) {
                final messages = state.messages;

                if (messages.isEmpty) {
                  return SliverFillRemaining(
                    child: SendWelcomMessage(
                      chatData: chatData,
                      currentUser: currentUser,
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    addAutomaticKeepAlives:
                        true, // يحتفظ بالـ widgets اللي فيها KeepAlive
                    addRepaintBoundaries: true,
                    childCount: messages.length,
                    (context, index) {
                      final msg = messages[index];
                      final isMy = msg.senderId == myId;
                      final isImage =
                          msg.privateMessageType == PrivateMessageType.image;

                      // Key ثابت — يمنع Flutter من إعادة بناء الـ widget لما الـ list تتغير
                      final stableKey = ValueKey(msg.messageId ?? msg.tempId);

                      return BlocBuilder<
                        SelectMessagesCubit,
                        SelectMessagesState
                      >(
                        buildWhen: (prev, curr) {
                          // rebuild الرسالة دي بس لو الـ selection بتاعتها اتغيرت
                          if (curr is ClearSelection) return true;
                          if (curr is! AddSelectMessages &&
                              curr is! RemoveSelectMessages) {
                            return false;
                          }
                          return context.read<SelectMessagesCubit>().isSelected(
                                msg,
                              ) !=
                              (prev is AddSelectMessages
                                  ? context
                                        .read<SelectMessagesCubit>()
                                        .isSelected(msg)
                                  : false);
                        },
                        builder: (context, selState) {
                          final cubit = context.read<SelectMessagesCubit>();
                          final isSelected = cubit.isSelected(msg);

                          return AnimatedContainer(
                            key: stableKey,
                            duration: const Duration(milliseconds: 150),
                            margin: EdgeInsets.only(bottom: isSelected ? 2 : 5),
                            padding: isSelected
                                ? const EdgeInsets.symmetric(vertical: 5)
                                : EdgeInsets.zero,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: isSelected
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.transparent,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  if (cubit.selectedMessages.isNotEmpty &&
                                      msg.senderId == myId) {
                                    cubit.selectMessage(msg);
                                    return;
                                  }
                                  if (isImage &&
                                      msg.privateMessageStatus !=
                                          PrivateMessageStatus.sending) {
                                    final sender =
                                        msg.sender ??
                                        UsersCache.getUser(msg.senderId);
                                    context.push(
                                      Routes.viewImage,
                                      extra: ViewImageParams(
                                        imageUrl: msg.localPath ?? msg.content,
                                        senderName: sender?.name ?? 'Unknown',
                                        messageData: msg,
                                      ),
                                    );
                                  }
                                },
                                onLongPress: () {
                                  if (cubit.selectedMessages.isEmpty &&
                                      msg.senderId == myId) {
                                    cubit.selectMessage(msg);
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment: isMy
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    MessageContent(
                                      isMy: isMy,
                                      message: msg,
                                      chatId: chatData.chatId,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              }

              if (state is FetchPrivateMessagesfailure) {
                return SliverFillRemaining(
                  child: Center(
                    child: CustomText( text: state.errMessage,style: AppTextStyles.bodyMedium,),
                  ),
                );
              }

              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            },
          )
       ;
  }
}

