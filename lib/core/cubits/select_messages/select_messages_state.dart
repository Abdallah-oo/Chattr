part of 'select_messages_cubit.dart';

@immutable
sealed class SelectMessagesState {}

final class SelectMessagesInitial extends SelectMessagesState {}

final class AddSelectMessages extends SelectMessagesState {}

final class RemoveSelectMessages extends SelectMessagesState {}

final class DeleteMessagesSuccess extends SelectMessagesState {}

final class DeleteMessagesLoading extends SelectMessagesState {}

final class DeleteMessagesFailure extends SelectMessagesState {
  final String errorMessage;
  DeleteMessagesFailure({required this.errorMessage});
}

final class ClearSelection extends SelectMessagesState {}

final class CopySelectedImages extends SelectMessagesState {}
