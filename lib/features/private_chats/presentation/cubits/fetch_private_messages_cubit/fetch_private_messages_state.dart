part of 'fetch_private_messages_cubit.dart';

@immutable
sealed class FetchPrivateMessagesState {
 const FetchPrivateMessagesState();
}

final class FetchPrivateMessagesInitial extends FetchPrivateMessagesState {}

final class FetchPrivateMessagesLoading extends FetchPrivateMessagesState {}

final class FetchPrivateMessagesSuccess extends FetchPrivateMessagesState {
  final List<PrivateMessageModel> messages;
  final String chatId; // ← ضيف دي

  const FetchPrivateMessagesSuccess({
    required this.messages,
    required this.chatId,
  });
}

final class FetchPrivateMessagesfailure extends FetchPrivateMessagesState {
  final String errMessage;
 const FetchPrivateMessagesfailure({required this.errMessage});
}
