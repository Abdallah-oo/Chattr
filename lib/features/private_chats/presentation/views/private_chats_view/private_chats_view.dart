import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:messenger_clone0/core/cubits/search/search_cubit.dart';
import 'package:messenger_clone0/core/utils/di/get_it.dart';
import 'package:messenger_clone0/core/widgets/custom_appbar.dart';
import 'package:messenger_clone0/features/private_chats/data/repos/add_friend_repo/add_friend_repo.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/add_friend_cubit/add_friend_cubit.dart';
import 'package:messenger_clone0/features/private_chats/presentation/views/private_chats_view/private_chats_view_body.dart';
import 'package:messenger_clone0/features/private_chats/presentation/views/private_chats_view/widgets/add_friend_bottom_sheet.dart';

class PrivateChatsView extends StatelessWidget {
  const PrivateChatsView({super.key});
  void showAddFriendBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: BlocProvider(
            create: (_) => AddFriendCubit(getIt<AddFriendRepo>()),
            child: const AddFriendBottomSheet(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: BlocProvider(
        create: (context) => SearchCubit(),
        child: Scaffold(
          appBar: CustomAppBar(
            title: 'Private Chats',
            actions: [
              GestureDetector(
                onTap: () => showAddFriendBottomSheet(context),
                child: const Icon(Icons.add_comment),
              ),
              Gap(10),
            ],
          ),
          body: const SafeArea(child: PrivateChatsViewBody()),
        ),
      ),
    );
  }
}
