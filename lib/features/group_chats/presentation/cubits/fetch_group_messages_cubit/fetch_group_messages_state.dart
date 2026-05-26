part of 'fetch_group_messages_cubit.dart';

@immutable
sealed class FetchGroupMessagesState {}

final class FetchGroupMessagesInitial extends FetchGroupMessagesState {}

final class FetchGroupMessagesLoading extends FetchGroupMessagesState {}

final class FetchGroupMessagesSuccess extends FetchGroupMessagesState {
  final String groupId;
  final List<GroupMessageModel> messages;
  
  FetchGroupMessagesSuccess({required this.messages, required this.groupId});
}

final class FetchMoreGroupMessages extends FetchGroupMessagesState {
  final List<GroupMessageModel> messages;
  FetchMoreGroupMessages({required this.messages});
}

final class FetchGroupMessagesFailure extends FetchGroupMessagesState {
  final String errorMessage;
  FetchGroupMessagesFailure({required this.errorMessage});
}
