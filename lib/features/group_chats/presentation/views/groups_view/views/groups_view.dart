import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger_clone0/core/routing/routes.dart';
import 'package:messenger_clone0/core/widgets/custom_appbar.dart';
import 'package:messenger_clone0/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:messenger_clone0/features/group_chats/presentation/views/groups_view/views/groups_view_body.dart';

class GroupsView extends StatelessWidget {
  const GroupsView({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: CustomAppBar(
          title: "Groups",
          actions: [
            GestureDetector(
              onTap: () => context.push(Routes.creatGroup, extra: context.read<FetchContactsCubit>(),),
              child: Icon(Icons.group_add_rounded),
            ),
            Gap(10),
          ],
        ),
        body: GroupsViewBody(),
      ),
    );
  }
}
