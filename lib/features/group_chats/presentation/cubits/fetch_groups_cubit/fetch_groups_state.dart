part of 'fetch_groups_cubit.dart';

@immutable
sealed class FetchGroupsState {}

final class FetchGroupsInitial extends FetchGroupsState {}

final class FetchGroupsLoading extends FetchGroupsState {}

final class FetchGroupsSuccess extends FetchGroupsState {
  final List<GroupModel> groups;

  FetchGroupsSuccess({required this.groups,});
}

final class FetchGroupsFailure extends FetchGroupsState {
  final String errorMessage;
  FetchGroupsFailure({required this.errorMessage});
}
