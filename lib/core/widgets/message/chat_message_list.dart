import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/cache/users_cache.dart';
import 'package:chattr/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/message/widgets/message_content.dart';
import 'package:chattr/core/widgets/message/widgets/send_welcom_message.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

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

    return chatData is PrivateChatModel
        ?
          //private chat
          BlocBuilder<FetchPrivateMessagesCubit, FetchPrivateMessagesState>(
            buildWhen: (prev, curr) {
              if (curr is FetchPrivateMessagesLoading) return false;
              if (curr is! FetchPrivateMessagesSuccess) return true;
              return curr.chatId ==
                  chatData.chatId; // ← بناء بس لو الـ chatId مطابق
            },
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
                      final isMe = msg.senderId == myId;
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
                                  mainAxisAlignment: isMe
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    MessageContent(
                                      isMe: isMe,
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
                    child: CustomText(
                      text: state.errMessage,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                );
              }

              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            },
          )
        : //group chat
          BlocBuilder<FetchGroupMessagesCubit, FetchGroupMessagesState>(
            buildWhen: (prev, curr) {
              if (curr is FetchGroupMessagesLoading) return false;
              if (curr is! FetchGroupMessagesSuccess) return true;
              return curr.groupId ==
                  chatData.id; // ← بناء بس لو الـ chatId مطابق
            },
            builder: (context, state) {
              if (state is FetchGroupMessagesSuccess) {
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
                      GroupMessageModel msg;
                      UserModel? sender;
                      msg = messages[index];
                      if (msg.sender == null) {
                        sender = UsersCache.getUser(msg.senderId);
                        msg = msg.copyWith(sender: sender);
                      } else {
                        sender = msg.sender;
                      }

                      final isMe = msg.senderId == myId;
                      final isImage = msg.messageType == GroupMessageType.image;

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
                                      msg.status !=
                                          GroupMessageStatus.sending) {
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
                                  mainAxisAlignment: isMe
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                
                                    MessageContent(
                                      isMe: isMe,
                                      message: msg,
                                      chatId: chatData.id,
                                    ),
                                        if (!isMe) ...[
                                             const Gap(5),
                                      _SenderImage(sender: sender),
                                      
                                   
                                    ],
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

              if (state is FetchGroupMessagesFailure) {
                return SliverFillRemaining(
                  child: Center(
                    child: CustomText(
                      text: state.errorMessage,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                );
              }

              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            },
          );
  }
}

class _SenderImage extends StatelessWidget {
  const _SenderImage({required this.sender});

  final UserModel? sender;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 10,
      child: ClipOval(
        child: CachedNetworkImage(
          height: 30,
          width: 30,
          fit: BoxFit.fill,
          imageUrl:
              sender?.image ??
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
