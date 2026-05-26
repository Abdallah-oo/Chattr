part of 'send_group_message_cubit.dart';

@immutable
sealed class SendGroupMessageState {}

final class SendGroupMessageInitial extends SendGroupMessageState {}

final class SendGroupMessageLoading extends SendGroupMessageState {}

final class SendGroupMessageSuccess extends SendGroupMessageState {}

final class SendGroupMessageFailure extends SendGroupMessageState {
  final String errorMessage;
  SendGroupMessageFailure({required this.errorMessage});
}
