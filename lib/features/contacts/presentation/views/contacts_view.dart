import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/core/widgets/custom_appbar.dart';
import 'package:chattr/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo.dart';
import 'package:chattr/features/contacts/presentation/cubits/add_to_contacts_cubit/add_to_contacts_cubit.dart';
import 'package:chattr/features/contacts/presentation/views/contacts_view_body.dart';
import 'package:chattr/features/contacts/presentation/views/widgets/add_contact_bottom_sheet.dart';
import 'package:chattr/features/private_chats/data/repos/add_friend_repo/add_friend_repo.dart';
import 'package:chattr/features/private_chats/presentation/cubits/add_friend_cubit/add_friend_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ContactsView extends StatelessWidget {
  const ContactsView({super.key});

  void _showAddContactSheet(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: BlocProvider(
          create: (_) => AddToContactsCubit(getIt<AddToContactsRepo>()),
          child: const AddContactBottomSheet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: CustomAppBar(
          title: "Contacts",
          actions: [
            GestureDetector(
              onTap: () => _showAddContactSheet(context),
              child: const Icon(Icons.person_add_sharp),
            ),
            Gap(10),
          ],
        ),

        body: SafeArea(
          child: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => SearchCubit()),
              BlocProvider(
                create: (context) => AddFriendCubit(getIt<AddFriendRepo>()),
              ),
              BlocProvider.value(value: getIt<FetchPrivateChatsCubit>()),
            ],
            child: const ContactsViewBody(),
          ),
        ),
      ),
    );
  }
}
