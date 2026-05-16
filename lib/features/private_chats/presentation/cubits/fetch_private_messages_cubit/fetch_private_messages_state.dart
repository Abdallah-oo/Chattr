part of 'fetch_private_messages_cubit.dart';

@immutable
sealed class FetchPrivateMessagesState {}

final class FetchPrivateMessagesInitial extends FetchPrivateMessagesState {}

final class FetchPrivateMessagesLoading extends FetchPrivateMessagesState {}

final class FetchPrivateMessagesSuccess extends FetchPrivateMessagesState {
  final List<PrivateMessageModel> messages;
  FetchPrivateMessagesSuccess({required this.messages});
}

final class FetchPrivateMessagesfailure extends FetchPrivateMessagesState {
  final String errMessage;
  FetchPrivateMessagesfailure({required this.errMessage});
}
