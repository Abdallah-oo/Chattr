import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger_clone0/core/cubits/fetch_current_user_data/fetch_current_user_data_cubit.dart';
import 'package:messenger_clone0/core/routing/router_models.dart';
import 'package:messenger_clone0/core/routing/routes.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/add_friend_cubit/add_friend_cubit.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';

class ContactItem extends StatelessWidget {
  const ContactItem({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      color: AppColors.surface,
      elevation: 0.3,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 5),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            _Avatar(imageUrl: user.image),
            const Gap(10),
            _UserInfo(name: user.name, email: user.email),
            const Spacer(),
            BlocBuilder<FetchPrivateChatsCubit, FetchPrivateChatsState>(
              builder: (context, state) {
                List<PrivateChatModel> chats = [];

                if (state is FetchPrivateChatsSuccess) {
                  chats = state.chats;
                }

                return _MessageButton(
                  onTap: () => _navigateToChat(
                    context: context,
                    user: user,
                    chats: chats,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _navigateToChat({
  required BuildContext context,
  required UserModel user,
  required List<PrivateChatModel> chats,
}) async {
  final hasChat = chats.any((chat) => chat.friend?.id == user.id);

  if (!hasChat) {
    final addFriendCubit = context.read<AddFriendCubit>();
    await addFriendCubit.addFriend(email: user.email!);
    if (addFriendCubit.state is AddFriendSuccess) {
      final chat = (addFriendCubit.state as AddFriendSuccess).chat;
      final currentUser = context.read<FetchCurrentUserDataCubit>().currentUser;
      final PrivateChatParams chatData = PrivateChatParams(
        chatData: chat,
        curruntUser: currentUser!,
      );

      context.push(Routes.privateChatsBody, extra: chatData);
    }
  } else {
    final chat = chats.firstWhere((chat) => chat.friend?.id == user.id);
    final currentUser = context.read<FetchCurrentUserDataCubit>().currentUser;
    final PrivateChatParams chatData = PrivateChatParams(
      chatData: chat,
      curruntUser: currentUser!,
    );
    context.push(Routes.privateChatsBody, extra: chatData);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.imageUrl});
  final String? imageUrl;

  static const _fallback =
      'https://static.thenounproject.com/png/1856610-200.png';

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      child: ClipOval(
        child: CachedNetworkImage(
          fit: BoxFit.cover,
          imageUrl: imageUrl ?? _fallback,
          placeholder: (_, _) => const CupertinoActivityIndicator(
            color: Colors.white54,
            radius: 9,
          ),
          errorWidget: (_, _, _) => const Icon(
            Icons.image_not_supported_outlined,
            color: Colors.red,
            size: 40,
          ),
        ),
      ),
    );
  }
}

class _UserInfo extends StatelessWidget {
  const _UserInfo({this.name, this.email});
  final String? name;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(text: name ?? '', style: AppTextStyles.bodyMedium),
        CustomText(text: email ?? '', style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _MessageButton extends StatelessWidget {
  const _MessageButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddFriendCubit, AddFriendState>(
      buildWhen: (prev, curr) =>
          prev is AddFriendLoading || curr is AddFriendLoading,
      builder: (context, state) {
        final bool isLoadind = state is AddFriendLoading;
        return InkWell(
          onTap: onTap,
          child: isLoadind
              ? const CircularProgressIndicator(color: AppColors.primary)
              : Icon(Icons.message, color: AppColors.primary),
        );
      },
    );
  }
}
