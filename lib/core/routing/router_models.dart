
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';


//!private chats
class PrivateChatParams {
  final PrivateChatModel chatData;
  final FetchPrivateMessagesCubit messagesCubit;
  final FetchPrivateChatsCubit chatCubit;
  final UserModel curruntUser;
  PrivateChatParams({
    required this.chatData,
    required this.curruntUser,
    required this.messagesCubit,
    required this.chatCubit,
  });
}



//!shared
class ViewImageParams {
  final String imageUrl;
  final String senderName;
  final dynamic messageData;
  ViewImageParams({
    required this.imageUrl,
    required this.senderName,
    required this.messageData,
  });
}
