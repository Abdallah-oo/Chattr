part of 'select_messages_cubit.dart';

@immutable
sealed class SelectMessagesState {}

final class SelectMessagesInitial extends SelectMessagesState {}

final class AddSelectMessages extends SelectMessagesState {}

final class RemoveSelectMessages extends SelectMessagesState {}


final class ClearSelection extends SelectMessagesState {}

