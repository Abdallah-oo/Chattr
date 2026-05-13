part of 'add_to_contacts_cubit.dart';

sealed class AddToContactsState {}

final class AddToContactsInitial extends AddToContactsState {}

final class AddToContactsLoading extends AddToContactsState {}

final class AddToContactsSuccess extends AddToContactsState {
  final UserModel contact;
  AddToContactsSuccess({required this.contact});
}

final class AddToContactsFailure extends AddToContactsState {
  final String errorMessage;
  AddToContactsFailure({required this.errorMessage});
}
