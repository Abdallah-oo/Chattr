part of 'fetch_private_chats_cubit.dart';

@immutable
sealed class FetchPrivateChatsState {}

final class FetchPrivateChatsInitial extends FetchPrivateChatsState {}

final class FetchPrivateChatsloading extends FetchPrivateChatsState {}

final class FetchPrivateChatsSuccess extends FetchPrivateChatsState {
  final List<PrivateChatModel> chats;

  FetchPrivateChatsSuccess({required this.chats});
}

final class FetchChatsFailure extends FetchPrivateChatsState {
  final String errorMessage;
  FetchChatsFailure({required this.errorMessage});
}
