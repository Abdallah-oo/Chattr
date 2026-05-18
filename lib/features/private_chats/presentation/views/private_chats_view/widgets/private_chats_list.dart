import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:messenger_clone0/core/cubits/fetch_current_user_data/fetch_current_user_data_cubit.dart';
import 'package:messenger_clone0/core/cubits/search/search_cubit.dart';
import 'package:messenger_clone0/core/routing/router_models.dart';
import 'package:messenger_clone0/core/routing/routes.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:messenger_clone0/features/private_chats/presentation/views/private_chats_view/widgets/unread_count_badge.dart';

class PrivateChatsList extends StatelessWidget {
  const PrivateChatsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchPrivateChatsCubit, FetchPrivateChatsState>(
        buildWhen: (prev, curr) {
        // متبنيش على loading لو في chats موجودة قبل كده
        if (curr is FetchPrivateChatsloading &&
            prev is FetchPrivateChatsSuccess) {
          return false;
        }
        return true;
      },
      builder: (context, state) {
        if (state is FetchPrivateChatsSuccess) {
          final currentUser = context
              .select<FetchCurrentUserDataCubit, UserModel?>(
                (cubit) => cubit.currentUser,
              );

          if (currentUser == null) {
            return const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            );
          }

          final privateChats = state.chats;

          if (privateChats.isEmpty) {
            return const SliverFillRemaining(
              child: Center(
                child: CustomText(
                  text: '💬 No chats yet',
                  style: AppTextStyles.headlineMedium,
                ),
              ),
            );
          }

          return BlocBuilder<SearchCubit, SearchState>(
            builder: (context, state) {
              final isSearchActive = state is SearchActive;

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  childCount: isSearchActive
                      ? state.filteredList.length
                      : privateChats.length,
                  (context, index) {
                    final chat = isSearchActive
                        ? state.filteredList[index] as PrivateChatModel
                        : privateChats[index];
                    return _ChatListItem(
                      key: ValueKey(chat.chatId),
                      chat: chat,
                      currentUser: currentUser,
                    );
                  },
                ),
              );
            },
          );
        }

        if (state is FetchChatsFailure) {
          return SliverFillRemaining(
            child: Center(
              child: CustomText(
                text: state.errorMessage,
                style: AppTextStyles.bodySmall,
              ),
            ),
          );
        }

        return SliverFillRemaining(
          child: Center(
            child: CupertinoActivityIndicator(color: Colors.grey, radius: 12),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE CHAT ITEM — widget منفصل عشان الـ rebuild يكون isolated
// ─────────────────────────────────────────────────────────────────────────────

class _ChatListItem extends StatelessWidget {
  const _ChatListItem({
    super.key,
    required this.chat,
    required this.currentUser,
  });

  final PrivateChatModel chat;
  final UserModel currentUser;

  @override
  Widget build(BuildContext context) {
    final privateChatParams = PrivateChatParams(
      chatData: chat,
      curruntUser: currentUser,
   
    );

    return GestureDetector(
      onTap: () =>
          context.push(Routes.privateChatsBody, extra: privateChatParams),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Row(
          children: [
            _ChatAvatar(
              imageUrl: chat.friend?.image,
              isOnline: chat.friend?.isOnLine ?? false,
            ),
            const Gap(20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: chat.friend?.name ?? '',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const Gap(4),
                  _LastMessageText(
                    message: chat.lastMessage ?? '',
                    senderId: chat.lastMessageSenderId ?? '',
                    currentUserId: currentUser.id ?? '',
                    friendName: chat.friend?.name ?? '',
                  ),
                ],
              ),
            ),
            UnreadCountBadge(chat: chat),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LAST MESSAGE TEXT
// ─────────────────────────────────────────────────────────────────────────────

class _LastMessageText extends StatelessWidget {
  const _LastMessageText({
    required this.message,
    required this.senderId,
    required this.currentUserId,
    required this.friendName,
  });

  final String message;
  final String senderId;
  final String currentUserId;
  final String friendName;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) {
      return const CustomText(
       style:  TextStyle(color: Colors.grey, fontSize: 10),
        text: '💬 Start your first conversation',
      );
    }

    final isMe = senderId == currentUserId;
    final prefix = isMe ? 'You: ' : '$friendName: ';
    final isRtl = Bidi.detectRtlDirectionality(message);

    return RichText(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      text: TextSpan(
        style: const TextStyle(color: Colors.grey, fontSize: 10),
        children: [
          TextSpan(
            text: prefix,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: message),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR
// ─────────────────────────────────────────────────────────────────────────────

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.imageUrl, required this.isOnline});

  final String? imageUrl;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                const Color.fromARGB(255, 26, 102, 234).withOpacity(0.7),
                const Color.fromARGB(255, 64, 198, 251).withOpacity(0.7),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: CachedNetworkImage(
              imageUrl: imageUrl ?? '',
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (_, _, _) => Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.person, color: Colors.grey, size: 26),
              ),
            ),
          ),
        ),
        if (isOnline)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
