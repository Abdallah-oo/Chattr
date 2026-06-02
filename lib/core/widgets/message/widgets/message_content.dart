import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/message/widgets/audio_message_widget.dart';
import 'package:chattr/core/widgets/message/widgets/image_message_widget.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/send_group_message_cubit/send_group_message_cubit.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class MessageContent extends StatelessWidget {
  const MessageContent({
    super.key,
    required this.isMe,
    required this.message,
    required this.chatId,
  });

  final bool isMe;
  final dynamic message;
  final String chatId;

  ///retry send failed message
  void _retryMessage(BuildContext context) {
    if (message is PrivateMessageModel) {
      final failedMessage = message as PrivateMessageModel;
      context.read<SendPrivateMessageCubit>().retryMessage(failedMessage);
    } else if (message is GroupMessageModel) {
      final failedMessage = message as GroupMessageModel;
      context.read<SendGroupMessageCubit>().retryMessage(failedMessage);
    }
  }

  ///retry delete failed message
  void _retryDelete(BuildContext context) {
    if (message is PrivateMessageModel) {
      final privateMessage = message as PrivateMessageModel;
      final privateChatId = chatId;

      context.read<SendPrivateMessageCubit>().retryDelete(
        chatId: privateChatId,
        message: privateMessage,
      );
    } else if (message is GroupMessageModel) {
      final groupMessage = message as GroupMessageModel;
      final groupId = chatId;
      context.read<SendGroupMessageCubit>().retryDelete(
        groupId: groupId,
        message: groupMessage,
      );
    }
  }

  ///retry edit  message
  void _retryEdit(BuildContext context) {
    if (message is PrivateMessageModel) {
      final privateMessage = message as PrivateMessageModel;
      final privateChatId = chatId;
      final content = message.content;
      context.read<SendPrivateMessageCubit>().retryEditMessage(
        chatId: privateChatId,
        message: privateMessage,
        content: content,
      );
    } else if (message is GroupMessageModel) {
      final groupMessage = message as GroupMessageModel;
      final groupId = chatId;
      context.read<SendGroupMessageCubit>().retryEditMessage(
        content: message.content,
        groupId: groupId,
        message: groupMessage,
      );
    }
  }

  void _retry({required dynamic status, required BuildContext context}) {
    final retryActions = status is PrivateMessageStatus
        ? {
            PrivateMessageStatus.failed: _retryMessage,
            PrivateMessageStatus.deleteFailed: _retryDelete,
            PrivateMessageStatus.editingFaild: _retryEdit,
          }
        : {
            GroupMessageStatus.failed: _retryMessage,
            GroupMessageStatus.deleteFailed: _retryDelete,
            GroupMessageStatus.editingFaild: _retryEdit,
          };
    retryActions[status]?.call(context);
  }

  @override
  Widget build(BuildContext context) {
    final status = message is PrivateMessageModel
        ? (message as PrivateMessageModel).privateMessageStatus
        : (message as GroupMessageModel).status;

    return message is PrivateMessageModel
        ?
          //?private message content
          Row(
            children: [
              if ((isMe) &&
                  (status == PrivateMessageStatus.failed ||
                      status == PrivateMessageStatus.deleteFailed ||
                      status == PrivateMessageStatus.editingFaild)) ...[
                GestureDetector(
                  onTap: () => _retry(status: status, context: context),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.refresh, size: 16, color: Colors.white),
                  ),
                ),
                Gap(5),
              ],
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                        bottomRight: isMe
                            ? Radius.circular(10)
                            : Radius.circular(0),
                        bottomLeft: isMe
                            ? Radius.circular(0)
                            : Radius.circular(10),
                      ),
                      color: message.isDeleted == true
                          ? AppColors.primary.withOpacity(0.6)
                          : AppColors.primary,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: context.screenWidth * 0.5,
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        message.isDeleted == true
                            ? CustomText(
                                align: TextAlign.start,

                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: message.isDeleted == true ? 12 : 14,
                                ),

                                text: " message has been deleted ⊘",
                              )
                            :
                              ///privateMessage
                              message.privateMessageType ==
                                  PrivateMessageType.voice
                            ? AudioMessageWidget(audioMessage: message)
                            : message.privateMessageType ==
                                  PrivateMessageType.image
                            ? ImageMessageWidget(imageMessage: message)
                            : CustomText(
                                align: TextAlign.start,
                                style: AppTextStyles.headlineSmall.copyWith(
                                  fontSize: message.isDeleted == true ? 12 : 14,
                                  color: message.isDeleted == true
                                      ? Colors.grey
                                      : Colors.white,
                                ),
                                text: message.content,
                                maxLines: 1024,
                              ),
                        Gap(isMe ? 10 : 20),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            !isMe
                                ? SizedBox.shrink()
                                : message.isDeleted == true
                                ? SizedBox.shrink()
                                : _buildStatusIndicator(status),
                            Gap(50),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom: 8,
                    right: !isMe ? null : 5,
                    left: isMe ? null : 5,
                    child: CustomText(
                      style: AppTextStyles.bodySmall.copyWith(
                        color: message.isDeleted == true
                            ? Colors.grey
                            : Colors.white,
                      ),
                      text: (DateFormat(
                        'jm',
                      ).format(DateTime.parse((message.createdAt).toString()))),
                    ),
                  ),
                ],
              ),
            ],
          )
        :
          //?group message content
          Row(
            children: [
              if ((isMe) &&
                  (status == GroupMessageStatus.failed ||
                      status == GroupMessageStatus.deleteFailed ||
                      status == GroupMessageStatus.editingFaild)) ...[
                GestureDetector(
                  onTap: () => _retry(status: status, context: context),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.refresh, size: 16, color: Colors.white),
                  ),
                ),
                Gap(5),
              ],
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                        bottomRight: isMe
                            ? Radius.circular(10)
                            : Radius.circular(0),
                        bottomLeft: isMe
                            ? Radius.circular(0)
                            : Radius.circular(10),
                      ),
                      color: message.isDeleted == true
                          ? AppColors.primary.withOpacity(0.6)
                          : AppColors.primary,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: context.screenWidth * 0.5,
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if(!isMe)...[
                          Gap(2),
                          CustomText(
                            align: TextAlign.start,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 9
                            ),
                            text: message.sender?.name ?? "Unknown",
                          ),
                              Gap(4),

                        ],
                        message.isDeleted == true
                            ? CustomText(
                                align: TextAlign.start,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: message.isDeleted == true ? 12 : 14,
                                ),
                                text: " message has been deleted ⊘",
                              )
                            : message.messageType == GroupMessageType.voice
                            ? AudioMessageWidget(audioMessage: message)
                            : message.messageType == GroupMessageType.image
                            ? ImageMessageWidget(imageMessage: message)
                            : CustomText(
                                align: TextAlign.start,
                                style: AppTextStyles.headlineSmall.copyWith(
                                  fontSize: message.isDeleted == true ? 12 : 14,
                                  color: message.isDeleted == true
                                      ? Colors.grey
                                      : Colors.white,
                                ),
                                text: message.content,
                                maxLines: 1024,
                              ),
                        Gap(isMe ? 10 : 20),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            !isMe
                                ? SizedBox.shrink()
                                : message.isDeleted == true
                                ? SizedBox.shrink()
                                : _buildStatusIndicator(status),
                            Gap(50),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom: 8,
                    right: !isMe ? null : 5,
                    left: isMe ? null : 5,
                    child: CustomText(
                      style: AppTextStyles.bodySmall.copyWith(
                        color: message.isDeleted == true
                            ? Colors.grey
                            : Colors.white,
                      ),
                      text: (DateFormat(
                        'jm',
                      ).format(DateTime.parse((message.createdAt).toString()))),
                    ),
                  ),
                ],
              ),
            ],
          );
  }

  //..................................................................
  Widget _buildStatusIndicator(dynamic status) {
    if (status is PrivateMessageStatus) {
      switch (status) {
        case PrivateMessageStatus.sending:
          return Icon(
            Icons.access_time_rounded,
            size: 16,
            color: Colors.white70,
          );

        case PrivateMessageStatus.sent:
          return Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: Colors.white70,
          );

        case PrivateMessageStatus.failed:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);

        case PrivateMessageStatus.deleting:
          return Icon(
            Icons.access_time_rounded,
            size: 16,
            color: Colors.white70,
          );

        case PrivateMessageStatus.deleteFailed:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);

        case PrivateMessageStatus.editing:
          return Icon(
            Icons.access_time_rounded,
            size: 16,
            color: Colors.white70,
          );

        case PrivateMessageStatus.editingFaild:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);
      }
    } else {
      switch (status) {
        case GroupMessageStatus.sending:
          return Icon(
            Icons.access_time_rounded,
            size: 16,
            color: Colors.white70,
          );

        case GroupMessageStatus.sent:
          return Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: Colors.white70,
          );

        case GroupMessageStatus.failed:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);

        case GroupMessageStatus.deleting:
          return Icon(
            Icons.access_time_rounded,
            size: 16,
            color: Colors.white70,
          );

        case GroupMessageStatus.deleteFailed:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);

        case GroupMessageStatus.editing:
          return Icon(
            Icons.access_time_rounded,
            size: 16,
            color: Colors.white70,
          );

        case GroupMessageStatus.editingFaild:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);
      }
    }
    return SizedBox.shrink();
  }
}
