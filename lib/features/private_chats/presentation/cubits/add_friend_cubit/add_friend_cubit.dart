import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_chat_model.dart';
import 'package:messenger_clone0/features/private_chats/data/repos/add_friend_repo/add_friend_repo.dart';
part 'add_friend_state.dart';

class AddFriendCubit extends Cubit<AddFriendState> {
  AddFriendCubit(this._repo) : super(AddFriendInitial());
  final AddFriendRepo _repo;

  Future<void> addFriend({required String email}) async {
    emit(AddFriendLoading());
    final result = await _repo.addFriend(email);
    result.fold(
      (l) => emit(AddFriendFailure(errMessage: l.message)),
      (r) => emit(AddFriendSuccess(chat: r)),
    );
  }
}
