import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/core/widgets/custom_appbar.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/core/widgets/image/ui/pick_image.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/add_and_remove_admin_cubit/add_and_remove_admin_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/delete_group_cubit/delete_group_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/delete_member_cubit/delete_member_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/edit_group_data_cubit/edit_group_data_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/select_group_members_cubit/select_group_members_cubit.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ViewGroupMembers extends StatelessWidget {
  const ViewGroupMembers({super.key, required this.groupData});
  final GroupChatParams groupData;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: groupData.fetchGroupsCubit!,
      child: BlocBuilder<FetchGroupsCubit, FetchGroupsState>(
        builder: (context, state) {
          GroupChatParams updatedGroupData = groupData;

          if (state is FetchGroupsSuccess) {
            final GroupModel? updatedGroup = state.groups.firstWhereOrNull(
              (g) => g.id == groupData.groupData.id,
            );
            if (updatedGroup == null) {
              return Scaffold(
                appBar: AppBar(
                  leading: InkWell(
                    onTap: () => context.pop(),
                    child: Icon(CupertinoIcons.arrow_left),
                  ),
                ),
                body: Center(child: CustomText(text: "Group not found")),
              );
            }

            updatedGroupData = GroupChatParams(
              groupData: updatedGroup,
              currentUser: groupData.currentUser,
              memberData: updatedGroup.members ?? [],
            );
            final List<UserInGroup> members = List<UserInGroup>.from(
              updatedGroupData.memberData,
            );

            // ترتيب: Owner → Admins → Normal members
            final owner = members.firstWhere(
              (e) => e.user.id == updatedGroupData.groupData.createdBy,
            );
            final admins = members
                .where((e) => e.isAdmin && e.user.id != owner.user.id)
                .toList();
            final normalUsers = members.where((e) => !e.isAdmin).toList();

            members
              ..clear()
              ..add(owner)
              ..addAll(admins)
              ..addAll(normalUsers);

            final curruntUser = updatedGroupData.currentUser;
            final isCurruntUserAdmin = members
                .firstWhere((e) => e.user.id == curruntUser.id)
                .isAdmin;

            return MultiBlocListener(
              listeners: [
                BlocListener<AddAndRemoveAdminCubit, AddAndRemoveAdminState>(
                  listener: (context, state) {
                    if (state is AddAndRemoveAdminFailure) {
                      CustomSnackBar.error(context, state.errorMessage);
                    }
                  },
                ),
                BlocListener<DeleteMemberCubit, DeleteMemberState>(
                  listener: (context, state) {
                    if (state is DeleteMemberFailure) {
                      CustomSnackBar.error(context, state.erroMessage);
                    }
                  },
                ),
              ],
              child: Scaffold(
                appBar: CustomAppBar(
                  leading: GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                  ),
                  title: "Group Members",
                  actions: [
                    InkWell(
                      onTap: !isCurruntUserAdmin
                          ? null
                          : () {
                              context.pushReplacement(
                                Routes.editGroup,
                                extra: updatedGroupData,
                              );
                            },
                      child: isCurruntUserAdmin
                          ? Icon(CupertinoIcons.gear_alt)
                          : SizedBox.shrink(),
                    ),
                    Gap(10),
                  ],
                ),
                body: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _AdminBadge(
                      member: member,
                      isCurruntUserAdmin: isCurruntUserAdmin,
                      updatedGroupData: updatedGroupData,
                    );
                  },
                ),
              ),
            );
          } else if (state is FetchGroupsFailure) {
            return Scaffold(
              appBar: AppBar(
                leading: InkWell(
                  onTap: () => context.pop(),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                ),
              ),
              body: Center(child: Text(state.errorMessage)),
            );
          } else {
            return Scaffold(
              body: Center(
                child: CupertinoActivityIndicator(
                  color: Colors.grey,
                  radius: 12,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

class _AdminBadge extends StatefulWidget {
  const _AdminBadge({
    required this.member,
    required this.isCurruntUserAdmin,
    required this.updatedGroupData,
  });

  final UserInGroup member;
  final bool isCurruntUserAdmin;
  final GroupChatParams updatedGroupData;

  @override
  State<_AdminBadge> createState() => __AdminBadgeState();
}

class __AdminBadgeState extends State<_AdminBadge> {
  bool isLoadingAdmin = false;
  bool isLoadingDelete = false;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

        //  Avatar
        leading: CircleAvatar(
          radius: 20,
          child: ClipOval(
            child: CachedNetworkImage(
              height: 100,
              width: 100,
              fit: BoxFit.fill,
              imageUrl:
                  member.user.image ??
                  'https://static.thenounproject.com/png/1856610-200.png',
              placeholder: (context, url) =>
                  CupertinoActivityIndicator(color: Colors.white54, radius: 9),
              errorWidget: (context, url, error) => const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.red,
                size: 40,
              ),
            ),
          ),
        ),

        //  Name
        title: Text(
          member.user.name ?? '',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),

        //  Admin Badge
        subtitle: member.isAdmin
            ? Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "admin",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ),
              )
            : null,

        //  Actions
        trailing:
            widget.isCurruntUserAdmin &&
                member.user.id != widget.updatedGroupData.groupData.createdBy
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ///Toggle Admin
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isLoadingAdmin
                          ? null
                          : () async {
                              setState(() => isLoadingAdmin = true);

                              try {
                                await context
                                    .read<AddAndRemoveAdminCubit>()
                                    .addAdminAndRemove(
                                      groupId:
                                          widget.updatedGroupData.groupData.id!,
                                      userId: member.user.id!,
                                      isAdmin: member.isAdmin,
                                    );
                              } finally {
                                if (mounted) {
                                  setState(() => isLoadingAdmin = false);
                                }
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: isLoadingAdmin
                            ? const CupertinoActivityIndicator(radius: 6)
                            : Icon(
                                member.isAdmin
                                    ? Icons.person_remove
                                    : Icons.person_add,
                                size: 18,
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  /// Delete
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isLoadingDelete
                          ? null
                          : () async {
                              setState(() => isLoadingDelete = true);

                              try {
                                await context
                                    .read<DeleteMemberCubit>()
                                    .deleteMember(
                                      groupId:
                                          widget.updatedGroupData.groupData.id!,
                                      userId: member.user.id!,
                                    );
                              } finally {
                                if (mounted) {
                                  setState(() => isLoadingDelete = false);
                                }
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: isLoadingDelete
                            ? const CupertinoActivityIndicator(radius: 6)
                            : const Icon(
                                CupertinoIcons.delete,
                                size: 18,
                                color: Colors.red,
                              ),
                      ),
                    ),
                  ),
                ],
              )
            : member.user.id == widget.updatedGroupData.groupData.createdBy
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Creator",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

//-----------------------------
class EditGroup extends StatefulWidget {
  const EditGroup({super.key, required this.groupData});
  final GroupChatParams groupData;

  @override
  State<EditGroup> createState() => _EditGroupState();
}

class _EditGroupState extends State<EditGroup> {
  late TextEditingController groupNameController;

  final _formKey = GlobalKey<FormState>();
  @override
  void initState() {
    groupNameController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: getIt<FetchContactsCubit>()),
          BlocProvider.value(value: getIt<FetchGroupsCubit>()),
        ],
        child: Scaffold(
          appBar: CustomAppBar(
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
            ),
            title: "Edit Group",

            actions: [
              BlocBuilder<DeleteGroupCubit, DeleteGroupState>(
                buildWhen: (prev, curr) =>
                    curr is DeleteGroupCubitLoading ||
                    prev is DeleteGroupCubitLoading,

                builder: (context, state) {
                  final isLoading = state is DeleteGroupCubitLoading;
                  return InkWell(
                    onTap: isLoading
                        ? null
                        : () {
                            context.read<DeleteGroupCubit>().deleteGroup(
                              groupId: widget.groupData.groupData.id!,
                            );
                          },
                    child: isLoading
                        ? CupertinoActivityIndicator(radius: 9)
                        : Icon(CupertinoIcons.delete),
                  );
                },
              ),
              Gap(10),
            ],
          ),
          body: MultiBlocListener(
            listeners: [
              BlocListener<PickImageCubit, PickImageState>(
                listener: (context, state) {
                  if (state is PickImageFailure) {
                    CustomSnackBar.error(context, state.errorMessage);
                  }
                },
              ),
              BlocListener<EditGroupDataCubit, EditGroupDataState>(
                listener: (context, state) {
                  if (state is EditGroupDataSucess) {
                    CustomSnackBar.success(
                      context,
                      "update group data succesfully",
                    );
                    context.pop();
                  }
                  if (state is EditGroupDataFailure) {
                    CustomSnackBar.error(context, state.errorMessage);
                  }
                },
              ),

              BlocListener<DeleteGroupCubit, DeleteGroupState>(
                listener: (context, state) {
                  if (state is DeleteGroupCubitSucess) {
                    CustomSnackBar.success(
                      context,
                      "group deleted successfully",
                    );
                    context.pop();
                    context.pop();
                  }
                  if (state is DeleteGroupCubitFailure) {
                    CustomSnackBar.error(context, state.errorMessage);
                  }
                },
              ),
            ],
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Gap(20),
                                CustomText(
                                  text: "Change Photo",
                                  style: AppTextStyles.headlineSmall,
                                ),
                                Gap(20),

                                /// select new image
                                PickImageWidget(
                                  defaultImageUrl:
                                      widget.groupData.groupData.image,
                                  isProfile: true,
                                ),

                                Gap(20),
                                CustomText(
                                  text: "Change Group Name",
                                  style: AppTextStyles.headlineSmall,
                                ),
                                Gap(5),

                                ///change name
                                CustomTextField(
                                  hint: widget.groupData.groupData.name!,
                                  validation: (v) {
                                    return null;
                                  },
                                  controller: groupNameController,
                                ),

                                /// add members
                                Gap(15),
                                Divider(),
                                Gap(5),
                                CustomText(text: "Add Members"),
                                Gap(5),
                              ],
                            ),
                          ),

                          BlocBuilder<FetchContactsCubit, FetchContactsState>(
                            builder: (context, state) {
                              if (state is FetchContactsSuccess) {
                                final myContacts = state.contacts;
                                return _AddMembers(
                                  myContact: myContacts,
                                  groupData: widget.groupData,
                                );
                              } else if (state is FetchContactsFailure) {
                                return SliverFillRemaining(
                                  child: Center(
                                    child: Text(state.errorMessage),
                                  ),
                                );
                              } else {
                                return SliverFillRemaining(
                                  child: Center(
                                    child: CupertinoActivityIndicator(
                                      radius: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// svae changes button
                  _SaveChangesButton(
                    groupNameController: groupNameController,
                    groupData: widget.groupData.groupData,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
//------------------------------------------------------

class _AddMembers extends StatelessWidget {
  const _AddMembers({required this.myContact, required this.groupData});
  final List<UserModel> myContact;
  final GroupChatParams groupData;

  @override
  Widget build(BuildContext context) {
    final groupMemberIds = groupData.memberData
        .map((e) => e.user.id)
        .toSet(); // ← Set للبحث الأسرع

    // 2️⃣ فلتر الأعضاء اللي مش موجودين
    final List<UserModel> restMembers = myContact
        .where((user) => !groupMemberIds.contains(user.id))
        .toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(childCount: restMembers.length, (
        context,
        index,
      ) {
        return BlocBuilder<SelectGroupMembersCubit, SelectGroupMembersState>(
          builder: (context, state) {
            final selectedMembers = context
                .read<SelectGroupMembersCubit>()
                .selectedMembers
                .contains(restMembers[index]);
            return Container(
              margin: const EdgeInsets.fromLTRB(0, 6, 20, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: CheckboxListTile(
                value: selectedMembers,

                onChanged: (value) {
                  context.read<SelectGroupMembersCubit>().addMembers(
                    user: restMembers[index],
                  );
                },
                activeColor: AppColors.primary,
                checkColor: Colors.white,
                checkboxShape: CircleBorder(),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                dense: true,
                visualDensity: VisualDensity.compact,
                title: CustomText(
                  text: restMembers[index].name ?? "",
                  style: AppTextStyles.headlineSmall,
                ),
                subtitle: CustomText(
                  text: "Online",
                  style: AppTextStyles.bodySmall,
                ),
                secondary: CircleAvatar(
                  radius: 20,
                  child: ClipOval(
                    child: CachedNetworkImage(
                      height: 100,
                      width: 100,
                      fit: BoxFit.fill,
                      imageUrl:
                          restMembers[index].image ??
                          'https://i.pravatar.cc/150?img=3',
                      placeholder: (context, url) => CupertinoActivityIndicator(
                        color: Colors.white54,
                        radius: 9,
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ),
                ),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

//----------------------------------
class _SaveChangesButton extends StatelessWidget {
  const _SaveChangesButton({
    required this.groupNameController,
    required this.groupData,
  });

  final TextEditingController groupNameController;
  final GroupModel groupData;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: groupNameController,
      builder: (context, value, _) {
        final isEmpty = value.text.trim().isEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: BlocBuilder<PickImageCubit, PickImageState>(
            builder: (context, state) {
              final imageFile = context.read<PickImageCubit>().imageFile;
              return BlocBuilder<
                SelectGroupMembersCubit,
                SelectGroupMembersState
              >(
                builder: (context, state) {
                  final addedMembers = context
                      .read<SelectGroupMembersCubit>()
                      .selectedMembers;

                  return BlocBuilder<EditGroupDataCubit, EditGroupDataState>(
                    buildWhen: (prev, curr) =>
                        curr is EditGroupDataLoading ||
                        prev is EditGroupDataLoading,
                    builder: (context, state) {
                      final isLoading = state is EditGroupDataLoading;
                      return CustomButton(
                        color:
                            isEmpty && imageFile == null && addedMembers.isEmpty
                            ? AppColors.border
                            : null,
                        onPressed:
                            (!isEmpty ||
                                    imageFile != null ||
                                    addedMembers.isNotEmpty) &&
                                !isLoading
                            ? () {
                                final members = context
                                    .read<SelectGroupMembersCubit>()
                                    .selectedMembers;
                                context
                                    .read<EditGroupDataCubit>()
                                    .editGroupData(
                                      groupData: groupData,
                                      name: groupNameController.text.trim(),
                                      newImageFile: imageFile,
                                      members: members,
                                    );
                              }
                            : null,
                        raduis: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomText(text: "save"),
                            Gap(10),
                            isLoading
                                ? CupertinoActivityIndicator(
                                    color: Colors.grey,
                                    radius: 10,
                                  )
                                : SizedBox.shrink(),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
