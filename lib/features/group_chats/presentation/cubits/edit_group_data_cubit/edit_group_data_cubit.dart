import 'dart:io';

import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/data/repos/edit_group_data_repo/edit_group_data_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'edit_group_data_state.dart';

class EditGroupDataCubit extends Cubit<EditGroupDataState> {
  EditGroupDataCubit(this._editGroupDataRepo) : super(EditGroupDataInitial());
  final EditGroupDataRepo _editGroupDataRepo;
  Future<void> editGroupData({
    required GroupModel groupData,
    required String? name,
    required List<UserModel> members,
    required File? newImageFile,
  }) async {
    emit(EditGroupDataLoading());
    final result = await _editGroupDataRepo.editGrroupDataRepo(
      groupData: groupData,
      name: name,
      members: members,
      newImageFile: newImageFile,
    );
    result.fold(
      (e) => emit(EditGroupDataFailure(errorMessage: '$e')),
      (u) => emit(EditGroupDataSucess()),
    );
  }
}
