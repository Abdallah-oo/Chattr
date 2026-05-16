import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger_clone0/core/cubits/audio_cubit/audio_cubit.dart';
import 'package:messenger_clone0/core/cubits/download_image/download_image_cubit.dart';
import 'package:messenger_clone0/core/cubits/fetch_current_user_data/fetch_current_user_data_cubit.dart';
import 'package:messenger_clone0/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:messenger_clone0/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:messenger_clone0/core/routing/router_models.dart';
import 'package:messenger_clone0/core/routing/routes.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_auth_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_crud_services.dart';
import 'package:messenger_clone0/core/utils/di/get_it.dart';
import 'package:messenger_clone0/core/widgets/image/ui/view_image.dart';
import 'package:messenger_clone0/features/auth/data/repos/auth_repo.dart';
import 'package:messenger_clone0/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:messenger_clone0/features/auth/presentation/views/login_view/login_view.dart';
import 'package:messenger_clone0/features/auth/presentation/views/signup_view/signup_view.dart';
import 'package:messenger_clone0/features/contacts/data/repos/fetch_contacts_repo/fetch_contacts_repo.dart';
import 'package:messenger_clone0/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:messenger_clone0/features/private_chats/data/repos/fetch_private_chats_repo/fetch_private_chat_repo.dart';
import 'package:messenger_clone0/features/private_chats/data/repos/fetch_private_messages_repo/fetch_private_messages_repo.dart';
import 'package:messenger_clone0/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:messenger_clone0/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:messenger_clone0/features/private_chats/presentation/views/private_chat_body_view/private_chat_body_view.dart';
import 'package:messenger_clone0/root.dart';

abstract class AppRouter {
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
          final privateMessagesCubit = FetchPrivateMessagesCubit(
            auth: getIt<AuthService>(),
            client: getIt<SupabaseClientManager>(),
            repo: getIt<FetchPrivateMessagesRepo>(),
          );

          final chatsCubit = FetchPrivateChatsCubit(
            client: getIt<SupabaseClientManager>(),
            fetchMessages: privateMessagesCubit,
            repo: getIt<FetchPrivateChatRepo>(),
          );

          // اربط الـ messagesCubit بالـ chatsCubit عشان يحدّث الـ unread بعد markAllAsRead
          privateMessagesCubit.setChatsCubit(chatsCubit);

          return MultiBlocProvider(
            providers: [
              BlocProvider.value(value: privateMessagesCubit),
              BlocProvider.value(value: chatsCubit..fetchPrivateChats()),
              BlocProvider(
                create: (context) => FetchCurrentUserDataCubit(
                  auth: getIt<AuthService>(),
                  crud: getIt<SupabaseCrudServices>(),
                  client: getIt<SupabaseClientManager>(),
                )..fetchCurruntUserData(),
              ),
              BlocProvider(
                create: (context) => FetchContactsCubit(
                  getIt<FetchContactsRepo>(),
                  getIt<AuthService>(),
                )..fetchContacts(),
              ),
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
      //private chat body
      GoRoute(
        path: Routes.privateChatsBody,

        builder: (context, state) {
          final chatData = state.extra as PrivateChatParams;

          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => SelectMessagesCubit()),
              BlocProvider.value(value: chatData.chatCubit),

              BlocProvider.value(value: chatData.messagesCubit),
              BlocProvider(
                create: (context) => SendPrivateMessageCubit(
                  fetchCubit: chatData.messagesCubit,
                  repo: getIt<SendPrivateMessageRepo>(),
                ),
              ),
              BlocProvider(create: (context) => AudioCubit()),
              BlocProvider(create: (context) => PickImageCubit()),
            ],
            child: PrivateChatBodyView(
              chatData: chatData.chatData,
              user: chatData.curruntUser,
            ),
          );
        },
      ),
    ],
  );
}
