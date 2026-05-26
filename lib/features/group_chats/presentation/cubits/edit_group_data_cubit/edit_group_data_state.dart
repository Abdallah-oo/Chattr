part of 'edit_group_data_cubit.dart';

@immutable
sealed class EditGroupDataState {}

final class EditGroupDataInitial extends EditGroupDataState {}

final class EditGroupDataLoading extends EditGroupDataState {}

final class EditGroupDataSucess extends EditGroupDataState {}

final class EditGroupDataFailure extends EditGroupDataState {
  final String errorMessage;
  EditGroupDataFailure({required this.errorMessage});
}
