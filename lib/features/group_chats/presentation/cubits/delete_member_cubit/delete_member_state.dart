part of 'delete_member_cubit.dart';

@immutable
sealed class DeleteMemberState {}

final class DeleteMemberInitial extends DeleteMemberState {}

final class DeleteMemberLoading extends DeleteMemberState {}

final class DeleteMemberSuccess extends DeleteMemberState {}

final class DeleteMemberFailure extends DeleteMemberState {
  final String erroMessage;
  DeleteMemberFailure({required this.erroMessage});
}
