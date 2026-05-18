part of 'fetch_current_user_data_cubit.dart';



@immutable
sealed class FetchCurrentUserDataState {}

final class FetchCurrentUserDataInitial extends FetchCurrentUserDataState {}

final class FetchCurrentUserDataSuccess extends FetchCurrentUserDataState {}

final class FetchCurrentUserDataFailure extends FetchCurrentUserDataState {
  final String errorMessage;
  FetchCurrentUserDataFailure({required this.errorMessage});
}

final class FetchCurrentUserDataLoading extends FetchCurrentUserDataState {}
