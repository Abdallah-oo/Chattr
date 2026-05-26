part of 'select_group_members_cubit.dart';


@immutable
sealed class SelectGroupMembersState {}

final class SelectGroupMembersInitial extends SelectGroupMembersState {}
final class SuccessAddMember extends SelectGroupMembersState {}
final class SuccessDeleteMember extends SelectGroupMembersState {}
