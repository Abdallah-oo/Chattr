
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';


//!private chats
class PrivateChatParams {
  final PrivateChatModel chatData;
  final UserModel curruntUser;
  PrivateChatParams({
    required this.chatData,
    required this.curruntUser,

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
