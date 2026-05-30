import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chats_view/widgets/private_chats_list.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chats_view/widgets/private_chats_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class PrivateChatsViewBody extends StatelessWidget {
  const PrivateChatsViewBody({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(20),
              BlocProvider.value(
                value: context.read<SearchCubit>(),
                child: ChatSearchBar(),
              ),
              Gap(30),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          sliver: BlocListener<FetchPrivateChatsCubit, FetchPrivateChatsState>(
            listener: (BuildContext context, FetchPrivateChatsState state) {
              if (state is FetchChatsFailure) {
                // CustomSnackBar.error(context, state.errorMessage);
              }
            },
            child: PrivateChatsList(),
          ),
        ),
      ],
    );
  }
}
