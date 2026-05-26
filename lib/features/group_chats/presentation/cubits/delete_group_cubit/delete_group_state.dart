part of 'delete_group_cubit.dart';

@immutable
sealed class DeleteGroupState {}

final class DeleteGroupCubitInitial extends DeleteGroupState {}

final class DeleteGroupCubitLoading extends DeleteGroupState {}

final class DeleteGroupCubitSucess extends DeleteGroupState {}

final class DeleteGroupCubitFailure extends DeleteGroupState {
  final String errorMessage;
  DeleteGroupCubitFailure({required this.errorMessage});
}
