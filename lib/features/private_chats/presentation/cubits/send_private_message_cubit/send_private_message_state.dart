part of 'send_private_message_cubit.dart';

@immutable
sealed class SendPrivateMessageState {}

final class SendPrivateMessageInitial extends SendPrivateMessageState {}

final class SendPrivateMessageLoading extends SendPrivateMessageState {}

final class SendPrivateMessageSuccess extends SendPrivateMessageState {}

final class SendPrivateMessageFailure extends SendPrivateMessageState {
  final String errorMessage;

  SendPrivateMessageFailure({required this.errorMessage});
}

final class CancelSendImageState extends SendPrivateMessageState {}
