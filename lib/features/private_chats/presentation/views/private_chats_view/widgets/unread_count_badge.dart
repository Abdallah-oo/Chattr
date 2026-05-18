import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';

/// بياخد الـ unreadCount من الـ PrivateChatModel مباشرة —
/// مش محتاج BlocBuilder خالص
class UnreadCountBadge extends StatelessWidget {
  const UnreadCountBadge({super.key, required this.chat});

  final PrivateChatModel chat;

  @override
  Widget build(BuildContext context) {

    final count = chat.unreadCount;

    if (count == 0) {
      return chat.lastMessageTime == null
          ? const SizedBox.shrink()
          : SizedBox(
              width: 50,
              child: CustomText(
                text: DateFormat.jm().format(chat.lastMessageTime!),
                style: AppTextStyles.bodySmall.copyWith(fontSize: 9),
              ),
            );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CustomText(
       style: AppTextStyles.bodySmall,
        text: count > 99 ? '99+' : '$count',
        align: TextAlign.center,
      ),
    );
  }
}
