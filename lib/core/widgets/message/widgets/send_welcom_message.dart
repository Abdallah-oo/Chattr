import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/core/helpers/snack_bar.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/utils/extensions/responsive.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';

class SendWelcomMessage extends StatelessWidget {
  const SendWelcomMessage({
    super.key,
    required this.chatData,
    required this.currentUser,
  });

  final dynamic chatData;
  final UserModel currentUser;

  @override
  Widget build(BuildContext context) {
    return
    /// chat message
    BlocListener<SendPrivateMessageCubit, SendPrivateMessageState>(
      listener: (context, state) {
        if (state is SendPrivateMessageFailure) {
          CustomSnackBar.error(context, state.errorMessage);
        }
      },
      child: Center(
        child: BlocBuilder<SendPrivateMessageCubit, SendPrivateMessageState>(
          buildWhen: (prev, curr) =>
              curr is SendPrivateMessageLoading ||
              prev is SendPrivateMessageLoading,
          builder: (context, state) {
            final isLoading = state is SendPrivateMessageLoading;
            return InkWell(
              onTap: isLoading
                  ? null
                  : () {
                      context.read<SendPrivateMessageCubit>().sendTextMessage(
                        message: "Hi! Let’s start talking 👋",
                        chatId: chatData.chatId,
                        sender: currentUser,
                        senderId: currentUser.id!,
                      );
                    },
              child: Card(
                child: Padding(
                  padding:  EdgeInsets.symmetric(
                    horizontal: context.screenWidth*0.1,
                    vertical: 25,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomText( text: "👋",style: AppTextStyles.displayLarge,),
                      CustomText(
                       
                        text: " Say Hi! Let’s start talking",
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
