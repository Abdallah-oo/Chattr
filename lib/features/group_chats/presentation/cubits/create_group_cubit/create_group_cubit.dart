import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_auth_services.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/group_chats/data/repos/create_group_repo/create_group_repo.dart';

part 'create_group_state.dart';

class CreateGroupCubit extends Cubit<CreateGroupState> {
  CreateGroupCubit({required CreateGroupRepo repo, required AuthService auth})
    : _repo = repo,
      _auth = auth,
      super(CreateGroupInitial());

  final CreateGroupRepo _repo;
  final AuthService _auth;

 Future<void> creatGroup({
    required String groupName,
    required File groupImageFile,
    required List<UserModel> members,
  }) async {
    emit(CreateGroupLoading());

    final myId = _auth.currentUser!.id;

    // 1️⃣ upload الصورة
    final imageResult = await _repo.uploadGroupImage(groupImageFile);
    if (imageResult.isLeft()) {
      emit(
        CreateGroupfailure(
          errorMessage: imageResult.fold((l) => l.message, (_) => ''),
        ),
      );
      return;
    }
    final imageUrl = imageResult.fold((_) => '', (r) => r);

    // 2️⃣ إنشاء الـ group
    final groupResult = await _repo.createGroup(
      groupName: groupName,
      imageUrl: imageUrl,
      createdBy: myId,
    );
    if (groupResult.isLeft()) {
      emit(
        CreateGroupfailure(
          errorMessage: groupResult.fold((l) => l.message, (_) => ''),
        ),
      );
      return;
    }
    final groupId = groupResult.fold((_) => '', (r) => r);

    // 3️⃣ إضافة الـ members
    for (final member in members) {
      final memberResult = await _repo.addGroupMember(
        groupId: groupId,
        userId: member.id!,
      );
      if (memberResult.isLeft()) {
        emit(
          CreateGroupfailure(
            errorMessage: memberResult.fold((l) => l.message, (_) => ''),
          ),
        );
        return;
      }
    }

    await Future.delayed(const Duration(seconds: 1));
    emit(CreateGroupSuccess());
  }
}
