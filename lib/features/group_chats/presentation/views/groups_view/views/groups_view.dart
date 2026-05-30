import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/widgets/custom_appbar.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/group_chats/presentation/views/groups_view/views/groups_view_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

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
              onTap: () => context.push(
                Routes.creatGroup,
                extra: context.read<FetchContactsCubit>(),
              ),
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
