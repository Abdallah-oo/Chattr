part of 'fetch_contacts_cubit.dart';

sealed class FetchContactsState {}

final class FetchContactsInitial extends FetchContactsState {}

final class FetchContactsLoading extends FetchContactsState {}

final class FetchContactsSuccess extends FetchContactsState {
  final List<UserModel> contacts;
  FetchContactsSuccess({required this.contacts});
}

final class FetchContactsFailure extends FetchContactsState {
  final String errorMessage;
  FetchContactsFailure({required this.errorMessage});
}
