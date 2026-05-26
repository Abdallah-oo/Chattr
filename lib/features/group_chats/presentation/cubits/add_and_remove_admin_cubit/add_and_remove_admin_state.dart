part of 'add_and_remove_admin_cubit.dart';

@immutable
sealed class AddAndRemoveAdminState {}

final class AddAndRemoveAdminInitial extends AddAndRemoveAdminState {}

final class AddAndRemoveAdminSuccess extends AddAndRemoveAdminState {}

final class AddAndRemoveAdminLoading extends AddAndRemoveAdminState {
  AddAndRemoveAdminLoading();
}

final class AddAndRemoveAdminFailure extends AddAndRemoveAdminState {
  final String errorMessage;
  AddAndRemoveAdminFailure({required this.errorMessage});
}
