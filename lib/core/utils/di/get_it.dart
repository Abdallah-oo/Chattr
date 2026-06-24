import 'package:chattr/core/services/notification/notification_service.dart';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:chattr/features/auth/data/repos/auth_repo_impl.dart';
import 'package:chattr/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo.dart';
import 'package:chattr/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo_impl.dart';
import 'package:chattr/features/contacts/data/repos/fetch_contacts_repo/fetch_contacts_repo.dart';
import 'package:chattr/features/contacts/data/repos/fetch_contacts_repo/fetch_contacts_repo_impl.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/group_chats/data/repos/add_and_remove_admin_repo/add_and_remove_admin_repo.dart';
import 'package:chattr/features/group_chats/data/repos/add_and_remove_admin_repo/add_and_remove_admin_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/create_group_repo/create_group_repo.dart';
import 'package:chattr/features/group_chats/data/repos/create_group_repo/create_group_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/delete_member_repo/delete_member_repo.dart';
import 'package:chattr/features/group_chats/data/repos/delete_member_repo/delete_member_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/edit_group_data_repo/edit_group_data_repo.dart';
import 'package:chattr/features/group_chats/data/repos/edit_group_data_repo/edit_group_data_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_group_messages_repo/fetch_group_messages_repo.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_group_messages_repo/fetch_group_messages_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_groups_repo/fetch_groups_repo.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_groups_repo/fetch_groups_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/send_group_message_repo/send_group_message_repo.dart';
import 'package:chattr/features/group_chats/data/repos/send_group_message_repo/send_group_message_repo_impl.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:chattr/features/private_chats/data/repos/add_friend_repo/add_friend_repo.dart';
import 'package:chattr/features/private_chats/data/repos/add_friend_repo/add_friend_repo_impl.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_chats_repo/fetch_private_chat_repo.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_chats_repo/fetch_private_chat_repo_impl.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_messages_repo/fetch_private_messages_repo.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_messages_repo/fetch_private_messages_repo_impl.dart';
import 'package:chattr/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo.dart';
import 'package:chattr/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo_impl.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setUpGetIt() {
  //client manager
  getIt.registerLazySingleton<SupabaseClientManager>(
    () => SupabaseClientManager(),
  );
  //auth services
  getIt.registerLazySingleton<AuthService>(
    () => AuthService(getIt<SupabaseClientManager>()),
  );
  //crud services
  getIt.registerLazySingleton<SupabaseCrudServices>(
    () => SupabaseCrudServices(getIt<SupabaseClientManager>()),
  );
  //storage services
  getIt.registerLazySingleton<SupabaseStorage>(
    () => SupabaseStorage(getIt<SupabaseClientManager>()),
  );
    //notification services
  getIt.registerLazySingleton<NotificationService>(
    () => NotificationService(client: getIt<SupabaseClientManager>()),
  );
  // auth repo
  getIt.registerLazySingleton<AuthRepo>(
    () => AuthRepoImpl(
      getIt<AuthService>(),
      getIt<SupabaseCrudServices>(),
      getIt<SupabaseStorage>(),
      getIt<NotificationService>()
    ),
  );
  // add to contacts repo
  getIt.registerLazySingleton<AddToContactsRepo>(
    () => AddToContactsRepoImpl(
      getIt<SupabaseClientManager>(),
      getIt<AuthService>(),
      getIt<SupabaseCrudServices>(),
    ),
  );
  //Fetch Contacts repo
  getIt.registerLazySingleton<FetchContactsRepo>(
    () => FetchContactsRepoImpl(
      getIt<SupabaseClientManager>(),
      getIt<SupabaseCrudServices>(),
    ),
  );
  //add friend repo
  getIt.registerLazySingleton<AddFriendRepo>(
    () => AddFriendRepoImpl(
      getIt<SupabaseCrudServices>(),
      getIt<SupabaseClientManager>(),
    ),
  );
  //fetch private chats repo
  getIt.registerLazySingleton<FetchPrivateChatRepo>(
    () => FetchPrivateChatRepoImpl(
      getIt<AuthService>(),
      getIt<SupabaseClientManager>(),
    ),
  );
  //fetch private messages repo
  getIt.registerLazySingleton<FetchPrivateMessagesRepo>(
    () => FetchPrivateMessagesRepoImpl(getIt<SupabaseClientManager>()),
  );
  //send private message repo
  getIt.registerLazySingleton<SendPrivateMessageRepo>(
    () => SendPrivateMessageRepoImpl(
      crud: getIt<SupabaseCrudServices>(),
      storage: getIt<SupabaseStorage>(),
    ),
  );
  //fetch contacts cubit
  getIt.registerLazySingleton<FetchContactsCubit>(
    () => FetchContactsCubit(getIt<FetchContactsRepo>(), getIt<AuthService>()),
  );

  // fetch private messages cubit
  getIt.registerLazySingleton<FetchPrivateMessagesCubit>(
    () => FetchPrivateMessagesCubit(
      auth: getIt<AuthService>(),
      client: getIt<SupabaseClientManager>(),
      repo: getIt<FetchPrivateMessagesRepo>(),
    ),
  );
  //fetch private chats cubit
  getIt.registerLazySingleton<FetchPrivateChatsCubit>(() {
    final chatsCubit = FetchPrivateChatsCubit(
      client: getIt<SupabaseClientManager>(),
      fetchMessages: getIt<FetchPrivateMessagesCubit>(),
      repo: getIt<FetchPrivateChatRepo>(),
    );
    // setChatsCubit هنا مرة واحدة
    getIt<FetchPrivateMessagesCubit>().setChatsCubit(chatsCubit);
    return chatsCubit;
  });

  //?group chats
  //add and remove admin repo
  getIt.registerLazySingleton<AddAndRemoveAdminRepo>(
    () => AddAndRemoveAdminRepoImpl(getIt<SupabaseClientManager>()),
  );
  //create group repo
  getIt.registerLazySingleton<CreateGroupRepo>(
    () => CreateGroupRepoImpl(
      crud: getIt<SupabaseCrudServices>(),
      storage: getIt<SupabaseStorage>(),
    ),
  );

  //delete member repo
  getIt.registerLazySingleton<DeleteMemberRepo>(
    () => DeleteMemberRepoImpl(getIt<SupabaseClientManager>()),
  );

  //edit group data repo
  getIt.registerLazySingleton<EditGroupDataRepo>(
    () => EditGroupDataRepoImpl(
      crud: getIt<SupabaseCrudServices>(),
      storage: getIt<SupabaseStorage>(),
    ),
  );

  //fetch groups repo
  getIt.registerLazySingleton<FetchGroupsRepo>(
    () => FetchGroupsRepoImpl(getIt<SupabaseClientManager>()),
  );
  // fetch group messages repo
  getIt.registerLazySingleton<FetchGroupMessagesRepo>(
    () => FetchGroupMessagesRepoImpl(
      clientManager: getIt<SupabaseClientManager>(),
    ),
  );

  //send group message repo
  getIt.registerLazySingleton<SendGroupMessageRepo>(
    () => SendGroupMessageRepoImpl(
      crud: getIt<SupabaseCrudServices>(),
      storage: getIt<SupabaseStorage>(),
    ),
  );

  //fetch groups cubit
  getIt.registerLazySingleton<FetchGroupsCubit>(
    () => FetchGroupsCubit(
      auth: getIt<AuthService>(),
      client: getIt<SupabaseClientManager>(),
      repo: getIt<FetchGroupsRepo>(),
    ),
  );

  //fetch group messages cubit
  getIt.registerLazySingleton<FetchGroupMessagesCubit>(
    () => FetchGroupMessagesCubit(
      auth: getIt<AuthService>(),
      client: getIt<SupabaseClientManager>(),
      repo: getIt<FetchGroupMessagesRepo>(),
    ),
  );


}
