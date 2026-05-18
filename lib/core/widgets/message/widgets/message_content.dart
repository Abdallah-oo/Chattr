import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/utils/extensions/responsive.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/core/widgets/message/widgets/audio_message_widget.dart';
import 'package:messenger_clone0/core/widgets/message/widgets/image_message_widget.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_message_model.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';

class MessageContent extends StatelessWidget {
  const MessageContent({
    super.key,
    required this.isMy,
    required this.message,
    required this.chatId,
  });

  final bool isMy;
  final dynamic message;
  final String chatId;

  ///retry send failed message
  void _retryMessage(BuildContext context) {
    if (message is PrivateMessageModel) {
      final failedMessage = message as PrivateMessageModel;
      context.read<SendPrivateMessageCubit>().retryMessage(failedMessage);
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
    }
  }

  void _retry({required dynamic status, required BuildContext context}) {
    final retryActions = {
      PrivateMessageStatus.failed: _retryMessage,
      PrivateMessageStatus.deleteFailed: _retryDelete,
      PrivateMessageStatus.editingFaild: _retryEdit,
    };

    retryActions[status]?.call(context);
  }

  @override
  Widget build(BuildContext context) {
    final status = (message as PrivateMessageModel).privateMessageStatus;

    return Row(
      children: [
        if ((isMy) &&
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
                  bottomRight: isMy ? Radius.circular(10) : Radius.circular(0),
                  bottomLeft: isMy ? Radius.circular(0) : Radius.circular(10),
                ),
                color: message.isDeleted == true
                    ? AppColors.primary.withOpacity(0.6)
                    : AppColors.primary,
              ),
              constraints: BoxConstraints(maxWidth: context.screenWidth * 0.5),
              child: Column(
                crossAxisAlignment: isMy
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  message.isDeleted == true
                      ? CustomText(
                          align: TextAlign.start,
                          text: " message has been deleted ⊘",
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: message.isDeleted == true ? 12 : 14,
                          ),
                        )
                      :
                        ///privateMessage
                        message.privateMessageType == PrivateMessageType.voice
                      ? AudioMessageWidget(audioMessage: message)
                      : message.privateMessageType == PrivateMessageType.image
                      ? ImageMessageWidget(imageMessage: message)
                      : CustomText(
                          align: TextAlign.start,
                          text: message.content,
                          maxLines: 1024,
                          style: AppTextStyles.headlineSmall.copyWith(
                            fontSize: message.isDeleted == true ? 12 : 14,
                            color: message.isDeleted == true
                                ? Colors.grey
                                : Colors.white,
                          ),
                        ),
                  Gap(isMy ? 10 : 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      !isMy
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
              right: !isMy ? null : 5,
              left: isMy ? null : 5,
              child: CustomText(
                text: (DateFormat(
                  'jm',
                ).format(DateTime.parse((message.createdAt).toString()))),
                style: AppTextStyles.bodySmall.copyWith(
                 color: message.isDeleted == true ? Colors.grey : Colors.white,
                ),
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
    } 
    return SizedBox.shrink();
  }
}
