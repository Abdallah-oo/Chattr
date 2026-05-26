
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/core/cubits/search/search_cubit.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';
import 'package:messenger_clone0/core/widgets/custom_text_field.dart';
import 'package:messenger_clone0/features/group_chats/data/models/group_model.dart';
import 'package:messenger_clone0/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';

class GroupsSearchBar extends StatefulWidget {
  const GroupsSearchBar({super.key});

  @override
  State<GroupsSearchBar> createState() => _GroupsSearchBarState();
}

class _GroupsSearchBarState extends State<GroupsSearchBar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    _searchController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _searchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchGroupsCubit, FetchGroupsState>(
      builder: (context, state) {
        List<GroupModel> chats = [];
        if (state is FetchGroupsSuccess) {
          chats = state.groups;
        }

        return chats.isNotEmpty
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: CustomTextField(
                  controller: _searchController,
                  hint: "search",
                  validation: (v) {
                    return null;
                  },
                  onChange: (value) => context.read<SearchCubit>().search(
                    list: chats,
                    query: value,
                    searchBy: (item) => item.name,
                  ),

                  suffixIcon: Icon(
                    CupertinoIcons.search,
                    color: AppColors.inputBorder,
                  ),
                ),
              )
            : SizedBox.shrink();
      },
    );
  }
}
