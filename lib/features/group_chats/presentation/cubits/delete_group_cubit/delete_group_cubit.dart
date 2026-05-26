import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_crud_services.dart';
part 'delete_group_state.dart';

class DeleteGroupCubit extends Cubit<DeleteGroupState> {
  DeleteGroupCubit(this._crud) : super(DeleteGroupCubitInitial());
  final SupabaseCrudServices _crud ;
  Future<void> deleteGroup({required String groupId}) async {
    emit(DeleteGroupCubitLoading());
    try {
      await _crud.delete(table: "groups", column: "group_id", id: groupId);
      emit(DeleteGroupCubitSucess());
    } catch (e) {
      emit(DeleteGroupCubitFailure(errorMessage: "$e"));
    }
  }
}
