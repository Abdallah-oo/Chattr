import 'package:chattr/core/cubits/audio_cubit/audio_cubit.dart';
import 'package:chattr/core/cubits/download_image/download_image_cubit.dart';
import 'package:chattr/core/cubits/fetch_current_user_data/fetch_current_user_data_cubit.dart';
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/core/widgets/image/ui/view_image.dart';
import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:chattr/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';
import 'package:chattr/features/auth/presentation/cubits/reset_password_cubit/reset_password_cubit.dart';
import 'package:chattr/features/auth/presentation/cubits/signup-verification_cubit/signup_verification_cubit.dart';
import 'package:chattr/features/auth/presentation/views/forget_password_view/forget_password_view.dart';
import 'package:chattr/features/auth/presentation/views/login_view/login_view.dart';
import 'package:chattr/features/auth/presentation/views/set_new_password_view/set_new_password_view.dart';
import 'package:chattr/features/auth/presentation/views/signup_view/signup_view.dart';
import 'package:chattr/features/auth/presentation/views/verify_otp_view/verify_otp_view.dart';
import 'package:chattr/features/auth/presentation/views/verify_signup_otp_view/verify_signup_otp_view.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/group_chats/data/repos/add_and_remove_admin_repo/add_and_remove_admin_repo.dart';
import 'package:chattr/features/group_chats/data/repos/create_group_repo/create_group_repo.dart';
import 'package:chattr/features/group_chats/data/repos/delete_member_repo/delete_member_repo.dart';
import 'package:chattr/features/group_chats/data/repos/edit_group_data_repo/edit_group_data_repo.dart';
import 'package:chattr/features/group_chats/presentation/cubits/add_and_remove_admin_cubit/add_and_remove_admin_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/create_group_cubit/create_group_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/delete_group_cubit/delete_group_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/delete_member_cubit/delete_member_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/edit_group_data_cubit/edit_group_data_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/select_group_members_cubit/select_group_members_cubit.dart';
import 'package:chattr/features/group_chats/presentation/views/group_messages_view/views/group_messages_view.dart';
import 'package:chattr/features/group_chats/presentation/views/group_messages_view/widgets/view_group_members.dart';
import 'package:chattr/features/group_chats/presentation/views/groups_view/widgets/create_group.dart';
import 'package:chattr/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chat_body_view/private_chat_body_view.dart';
import 'package:chattr/root.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

abstract class AppRouter {
  static String? activeChatId;

  static final router = GoRouter(
    routes: [
      //login
      GoRoute(
        path: Routes.initial,
        builder: (context, state) => BlocProvider(
          create: (context) => AuthCubit(getIt<AuthRepo>()),
          child: LoginView(),
        ),
      ),

      ///signup
      GoRoute(
        path: Routes.signup,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => PickImageCubit()),
            BlocProvider(create: (context) => AuthCubit(getIt<AuthRepo>())),
          ],
          child: SignupView(),
        ),
      ),

      //Navigation Bar
      GoRoute(
        path: Routes.root,
        builder: (context, state) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) => FetchCurrentUserDataCubit(
                  auth: getIt<AuthService>(),
                  crud: getIt<SupabaseCrudServices>(),
                  client: getIt<SupabaseClientManager>(),
                )..fetchCurruntUserData(),
              ),

              BlocProvider(
                create: (_) => getIt<FetchContactsCubit>()..fetchContacts(),
              ),
              BlocProvider(create: (_) => getIt<FetchPrivateMessagesCubit>()),
              BlocProvider(
                create: (_) =>
                    getIt<FetchPrivateChatsCubit>()..fetchPrivateChats(),
              ),
              BlocProvider(
                create: (_) => getIt<FetchGroupsCubit>()..fetchGroups(),
              ),
              BlocProvider(create: (_) => getIt<FetchGroupMessagesCubit>()),
            ],
            child: Root(),
          );
        },
      ),

      //view image
      GoRoute(
        path: Routes.viewImage,
        builder: (context, state) {
          final imageInfo = state.extra as ViewImageParams;
          return BlocProvider(
            create: (context) => DownloadImageCubit(),
            child: ViewImage(imageInfo: imageInfo),
          );
        },
      ),
      //?private chat body
      GoRoute(
        path: Routes.privateChatsBody,

        builder: (context, state) {
          final chatData = state.extra as PrivateChatParams;

          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => SelectMessagesCubit()),
              BlocProvider(
                create: (context) => SendPrivateMessageCubit(
                  fetchCubit: getIt<FetchPrivateMessagesCubit>(),
                  repo: getIt<SendPrivateMessageRepo>(),
                ),
              ),
              BlocProvider(
                create: (context) => AudioCubit(getIt<SupabaseStorage>()),
              ),
              BlocProvider(create: (context) => PickImageCubit()),
            ],
            child: PrivateChatBodyView(
              chatData: chatData.chatData,
              user: chatData.curruntUser,
            ),
          );
        },
      ),
      //?group chat body
      //creat
      GoRoute(
        path: Routes.creatGroup,
        builder: (context, state) {
          final FetchContactsCubit contactsCubit =
              state.extra as FetchContactsCubit;
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) => CreateGroupCubit(
                  auth: getIt<AuthService>(),
                  repo: getIt<CreateGroupRepo>(),
                ),
              ),
              BlocProvider(create: (context) => PickImageCubit()),
              BlocProvider(create: (context) => SelectGroupMembersCubit()),
            ],
            child: CreatGroup(contactsCubit: contactsCubit),
          );
        },
      ),

      //group messages view
      GoRoute(
        path: Routes.groupMessages,
        builder: (context, state) {
          final GroupChatParams groupData = state.extra as GroupChatParams;

          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => PickImageCubit()),
              BlocProvider(
                create: (context) => AudioCubit(getIt<SupabaseStorage>()),
              ),

              BlocProvider(create: (context) => SelectMessagesCubit()),
            ],
            child: GroupMessagesView(groupData: groupData),
          );
        },
      ),

      //view group members
      GoRoute(
        path: Routes.viewGroupMembers,
        builder: (context, state) {
          final GroupChatParams groupData = state.extra as GroupChatParams;

          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) => AddAndRemoveAdminCubit(
                  repo: getIt<AddAndRemoveAdminRepo>(),
                ),
              ),
              BlocProvider(
                create: (context) =>
                    DeleteMemberCubit(getIt<DeleteMemberRepo>()),
              ),
              BlocProvider(
                create: (context) =>
                    DeleteGroupCubit(getIt<SupabaseCrudServices>()),
              ),
            ],
            child: ViewGroupMembers(groupData: groupData),
          );
        },
      ),

      //edit group
      GoRoute(
        path: Routes.editGroup,
        builder: (context, state) {
          final GroupChatParams groupData = state.extra as GroupChatParams;

          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) =>
                    EditGroupDataCubit(getIt<EditGroupDataRepo>()),
              ),
              BlocProvider(
                create: (context) =>
                    DeleteGroupCubit(getIt<SupabaseCrudServices>()),
              ),
              BlocProvider(create: (context) => SelectGroupMembersCubit()),
              BlocProvider(create: (context) => PickImageCubit()),
            ],
            child: EditGroup(groupData: groupData),
          );
        },
      ),

      //Forget Password
      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider(
            create: (context) => ResetPasswordCubit(getIt<AuthRepo>()),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: Routes.forgetPassword,
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                child: ForgotPasswordView(),
                transitionsBuilder: (context, animation, _, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 400),
              );
            },
          ),
          GoRoute(
            path: Routes.verifyOtp,
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                child: VerifyOtpView(),
                transitionsBuilder: (context, animation, _, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 400),
              );
            },
          ),

          GoRoute(
            path: Routes.setNewPassword,
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                child: SetNewPasswordView(),
                transitionsBuilder: (context, animation, _, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 400),
              );
            },
          ),
        ],
      ),

      //signup verification
      GoRoute(
        path: Routes.signupVerification,
        pageBuilder: (context, state) {
          final SignupVerificationParams params = state.extra as SignupVerificationParams;
          return CustomTransitionPage(
            child: BlocProvider(
              create: (context) =>
                  SignupVerificationCubit(getIt<AuthRepo>(), email: params.email, name: params.name, image: params.image),
              child: VerifySignupOtpView(),
            ),
            transitionsBuilder: (context, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          );
        },
      ),
    ],
  );
}
