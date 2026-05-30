import 'package:chattr/features/group_chats/data/repos/add_and_remove_admin_repo/add_and_remove_admin_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'add_and_remove_admin_state.dart';

class AddAndRemoveAdminCubit extends Cubit<AddAndRemoveAdminState> {
  AddAndRemoveAdminCubit({required AddAndRemoveAdminRepo repo})
    : _repo = repo,
      super(AddAndRemoveAdminInitial());

  final AddAndRemoveAdminRepo _repo;
  int? locaIndex;
  Future<void> addAdminAndRemove({
    required String groupId,
    required String userId,
    required bool isAdmin,
  }) async {
    emit(AddAndRemoveAdminLoading());
    final result = await _repo.addAdminAndRemove(
      groupId: groupId,
      userId: userId,
      isAdmin: isAdmin,
    );
    result.fold(
      (e) => emit(AddAndRemoveAdminFailure(errorMessage: "$e")),
      (u) => emit(AddAndRemoveAdminSuccess()),
    );
  }
}
