import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/features/group_chats/data/repos/delete_member_repo/delete_member_repo.dart';

part 'delete_member_state.dart';

class DeleteMemberCubit extends Cubit<DeleteMemberState> {
  DeleteMemberCubit(this._repo) : super(DeleteMemberInitial());
  final DeleteMemberRepo _repo;
  Future<void> deleteMember({
    required String groupId,
    required String userId,
  }) async {
    emit(DeleteMemberLoading());
    final result = await _repo.deleteMember(groupId: groupId, userId: userId);
    result.fold(
      (e) => emit(DeleteMemberFailure(erroMessage: '$e')),
      (u) => emit(DeleteMemberSuccess()),
    );
  }
}
