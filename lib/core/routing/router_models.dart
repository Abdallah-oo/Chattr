

//?private chats
import 'dart:io';

import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';

class PrivateChatParams {
  final PrivateChatModel chatData;
  final UserModel curruntUser;
  PrivateChatParams({required this.chatData, required this.curruntUser});
}

//?shared
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

//?group chats
class GroupChatParams {
  final GroupModel groupData;
  final UserModel currentUser;
  final List<UserInGroup> memberData;
  final FetchGroupsCubit ?fetchGroupsCubit;

  GroupChatParams({
    required this.groupData,
    required this.currentUser,
    required this.memberData, this.fetchGroupsCubit,
  });
}
//signup verification 
class SignupVerificationParams {
  final String email;
  final String name;
  final File image;

  SignupVerificationParams({
    required this.email,
    required this.name,
    required this.image,
  });
}
