import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:messenger_clone0/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:messenger_clone0/core/helpers/snack_bar.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_auth_services.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';
import 'package:messenger_clone0/core/utils/extensions/responsive.dart';
import 'package:messenger_clone0/core/widgets/audio/ui/audio_button.dart';
import 'package:messenger_clone0/core/widgets/custom_text_field.dart';
import 'package:messenger_clone0/core/widgets/image/ui/pick_image.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:messenger_clone0/features/private_chats/presentation/views/private_chat_body_view/widgets/image_view_container.dart';

class SendMessageField extends StatefulWidget {
  const SendMessageField({
    super.key,
    required this.chatData,
    required this.curruntUser,
    required AuthService auth,
  }) : _auth = auth;
  final dynamic chatData;
  final UserModel curruntUser;
  final AuthService _auth;
  @override
  State<SendMessageField> createState() => _SendMessageFieldState();
}

class _SendMessageFieldState extends State<SendMessageField> {
  late TextEditingController messageController;

  @override
  void initState() {
    messageController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override 
  Widget build(BuildContext context) {
    return
          //?private chat
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: MultiBlocListener(
              listeners: [
                BlocListener<SendPrivateMessageCubit, SendPrivateMessageState>(
                  listener: (context, state) {
                    if (state is SendPrivateMessageSuccess) {
                      if (context.read<PickImageCubit>().imageFile != null) {
                        context.read<PickImageCubit>().deleteImage();
                      } else {
                        messageController.clear();
                      }
                    }
                  },
                ),

                ///group
                BlocListener<PickImageCubit, PickImageState>(
                  listener: (context, state) {
                    if (state is PickImageFailure) {
                      CustomSnackBar.error(context, state.errorMessage);
                    }
                  },
                ),
              ],
              child: Column(
                children: [
                  ImageViewContainer(),

                  SizedBox(
                    width: context.screenWidth,
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 2,
                            controller: messageController,
                            hint: "message",
                            validation: (v) {
                              return null;
                            },
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.emoji_emotions),
                                Gap(8),
                                GestureDetector(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (ctx) {
                                        return BlocProvider.value(
                                          value: context.read<PickImageCubit>(),
                                          child: PickImageWidget(),
                                        );
                                      },
                                    );
                                  },
                                  child: Icon(Icons.add_photo_alternate),
                                ),
                                Gap(10),
                              ],
                            ),
                          ),
                        ),
                        Gap(20),

                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: messageController,
                          builder: (context, value, _) {
                            final isEmpty = value.text.trim().isEmpty;

                            return BlocBuilder<PickImageCubit, PickImageState>(
                              builder: (context, state) {
                                final imagePath = context
                                    .read<PickImageCubit>()
                                    .imageFile;
                                return
                                /// friend chat
                                BlocBuilder<
                                  SendPrivateMessageCubit,
                                  SendPrivateMessageState
                                >(
                                  buildWhen: (prev, curr) =>
                                      prev is SendPrivateMessageLoading ||
                                      curr is SendPrivateMessageLoading,
                                  builder: (context, state) {
                                    final isLoading =
                                        state is SendPrivateMessageLoading;
                                    return InkWell(
                                      onTap:
                                          (!isEmpty || imagePath != null) &&
                                              !isLoading
                                          ? () {
                                              if (imagePath != null) {
                                                context
                                                    .read<
                                                      SendPrivateMessageCubit
                                                    >()
                                                    .sendImage(
                                                      imageFile: imagePath,
                                                      chatId: widget
                                                          .chatData
                                                          .chatId,
                                                      sender:
                                                          widget.curruntUser,
                                                      senderId: widget
                                                          .curruntUser
                                                          .id!,
                                                    );
                                              } else {
                                                final message =
                                                    messageController.text
                                                        .trim();
                                                messageController.clear();
                                                context
                                                    .read<
                                                      SendPrivateMessageCubit
                                                    >()
                                                    .sendTextMessage(
                                                      message: message,
                                                      chatId: widget
                                                          .chatData
                                                          .chatId,
                                                      sender:
                                                          widget.curruntUser,
                                                      senderId: widget
                                                          .curruntUser
                                                          .id!,
                                                    );
                                              }
                                            }
                                          : null,
                                      child: isEmpty && imagePath == null
                                          ? AudioRecordButton(
                                              sender: widget.curruntUser,
                                              chatId: widget.chatData.chatId,
                                              senderId: widget.curruntUser.id!,

                                              isGroup: false,
                                            )
                                          : SizedBox(
                                              height: 50,
                                              width: 40,
                                              child: Icon(
                                                Icons.send_sharp,
                                                color: AppColors.primary,
                                                size: 27,
                                              ),
                                            ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),

                        Gap(10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
       
  }
}
