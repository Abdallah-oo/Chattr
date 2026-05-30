import 'package:chattr/core/cubits/audio_cubit/audio_cubit.dart';
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/core/widgets/custom_appbar.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chat_body_view/private_chat_body_view_body.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chats_view/widgets/online_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class PrivateChatBodyView extends StatelessWidget {
  const PrivateChatBodyView({
    super.key,
    required this.chatData,
    required this.user,
  });
  final dynamic chatData;
  final UserModel user;

  void deletemessage({
    required List<dynamic> selected,
    required BuildContext context,
  }) {
    context.read<FetchPrivateMessagesCubit>().deletePrivateMessages(
      chatId: chatData.chatId!,
      messages: selected.cast<PrivateMessageModel>(),
    );

    context.read<SelectMessagesCubit>().clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => SelectMessagesCubit()),
          BlocProvider.value(value: getIt<FetchPrivateMessagesCubit>()),

          BlocProvider.value(value: getIt<FetchPrivateChatsCubit>()),
          BlocProvider(
            create: (context) => SendPrivateMessageCubit(
              fetchCubit: getIt<FetchPrivateMessagesCubit>(),
              repo: getIt<SendPrivateMessageRepo>(),
            ),
          ),
          BlocProvider(
            create: (context) => AudioCubit(getIt<SupabaseStorage>()),
          ),
          BlocProvider(create: (context) => PickImageCubit()),
        ],
        child: Scaffold(
          appBar: CustomAppBar(
            title: chatData.friend.name ?? "",
            titleItems: [OnlineStatusWidget(chatId: chatData.chatId!)],
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
                              onTap: () => deletemessage(
                                selected: selectedmessages,
                                context: context,
                              ),
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
          body: PrivateChatBodyViewBody(chatData: chatData, curruntUser: user),
        ),
      ),
    );
  }
}
