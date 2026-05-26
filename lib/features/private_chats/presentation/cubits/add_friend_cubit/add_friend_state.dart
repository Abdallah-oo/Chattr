part of 'add_friend_cubit.dart';

@immutable
sealed class AddFriendState {}

final class AddFriendInitial extends AddFriendState {}

final class AddFriendLoading extends AddFriendState {}

final class AddFriendSuccess extends AddFriendState {
  final PrivateChatModel chat;
  AddFriendSuccess({required this.chat});
}

final class AddFriendFailure extends AddFriendState {
  final String errMessage;

  AddFriendFailure({required this.errMessage});
}
