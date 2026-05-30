import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/contacts/presentation/views/widgets/contact_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ContactsViewBody extends StatefulWidget {
  const ContactsViewBody({super.key});

  @override
  State<ContactsViewBody> createState() => _ContactsViewBodyState();
}

class _ContactsViewBodyState extends State<ContactsViewBody> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchContactsCubit, FetchContactsState>(
      builder: (context, state) {
        return switch (state) {
          FetchContactsSuccess() => _buildBody(context, state.contacts),
          FetchContactsFailure() => Center(child: Text(state.errorMessage)),
          _ => Center(
            child: CupertinoActivityIndicator(color: Colors.grey, radius: 12),
          ),
        };
      },
    );
  }

  Widget _buildBody(BuildContext context, List<UserModel> contacts) {
    return Column(
      children: [
        if (contacts.isNotEmpty) Gap(20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SearchField(
            controller: _searchController,
            contacts: contacts,
          ),
        ),
        const Gap(10),
        Expanded(child: _ContactsList(contacts: contacts)),
      ],
    );
  }
}

// ─── Search Field ───────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.contacts});

  final TextEditingController controller;
  final List<UserModel> contacts;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      hint: "search",
      validation: (_) => null,
      onChange: (_) {
        context.read<SearchCubit>().search(
          list: contacts,
          query: controller.text.trim(),
          searchBy: (item) => (item as UserModel).name ?? '',
        );
      },
      suffixIcon: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, _, _) {
          final hasText = controller.text.trim().isNotEmpty;
          return hasText
              ? InkWell(
                  onTap: () {
                    controller.clear();
                    context.read<SearchCubit>().closeSearch();
                  },
                  child: const Icon(Icons.clear_rounded),
                )
              : const Icon(CupertinoIcons.search, color: AppColors.inputBorder);
        },
      ),
    );
  }
}

// ─── Contacts List ───────────────────────────────────────────────
class _ContactsList extends StatelessWidget {
  const _ContactsList({required this.contacts});

  final List<UserModel> contacts;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        final filtered = state is SearchActive
            ? state.filteredList.cast<UserModel>()
            : contacts;

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (_, index) => ContactItem(user: filtered[index]),
        );
      },
    );
  }
}
