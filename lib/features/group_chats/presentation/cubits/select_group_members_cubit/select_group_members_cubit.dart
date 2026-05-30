import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'select_group_members_state.dart';

class SelectGroupMembersCubit extends Cubit<SelectGroupMembersState> {
  SelectGroupMembersCubit() : super(SelectGroupMembersInitial());
  List<UserModel> selectedMembers = [];
  void addMembers({required UserModel user}) {
    if (selectedMembers.contains(user)) {
      selectedMembers.remove(user);
      emit(SuccessDeleteMember());
    } else {
      selectedMembers.add(user);
      emit(SuccessAddMember());
    }
  }

  void cleanMembers() {
    selectedMembers = [];
    emit(SelectGroupMembersInitial());
  }
}
