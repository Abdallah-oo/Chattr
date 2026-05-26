import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:messenger_clone0/core/cubits/search/search_cubit.dart';
import 'package:messenger_clone0/core/helpers/snack_bar.dart';
import 'package:messenger_clone0/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:messenger_clone0/features/group_chats/presentation/views/groups_view/widgets/groups_list.dart';
import 'package:messenger_clone0/features/group_chats/presentation/views/groups_view/widgets/groups_search_bar.dart';

class GroupsViewBody extends StatelessWidget {
  const GroupsViewBody({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(20),
              BlocProvider(
                create: (context) => SearchCubit(),
                child: GroupsSearchBar(),
              ),
              Gap(30),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 0, 0, 0),
          sliver: BlocListener<FetchGroupsCubit, FetchGroupsState>(
            listener: (context, state) {
              if (state is FetchGroupsFailure) {
                CustomSnackBar.error(context, state.errorMessage);
              }
            },
            child: Grouplist(),
          ),
        ),
      ],
    );
  }
}
