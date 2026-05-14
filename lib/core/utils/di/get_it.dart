import 'package:get_it/get_it.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_auth_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_crud_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_storage.dart';
import 'package:messenger_clone0/features/auth/data/repos/auth_repo.dart';
import 'package:messenger_clone0/features/auth/data/repos/auth_repo_impl.dart';
import 'package:messenger_clone0/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo.dart';
import 'package:messenger_clone0/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo_impl.dart';
import 'package:messenger_clone0/features/contacts/data/repos/fetch_contacts_repo/fetch_contacts_repo.dart';
import 'package:messenger_clone0/features/contacts/data/repos/fetch_contacts_repo/fetch_contacts_repo_impl.dart';
import 'package:messenger_clone0/features/private_chats/data/repos/add_friend_repo.dart';
import 'package:messenger_clone0/features/private_chats/data/repos/add_friend_repo_impl.dart';

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
    () => SupabaseStorage(
      storageFile: "users_image",
      clientManager: getIt<SupabaseClientManager>(),
    ),
  );
  // auth repo
  getIt.registerLazySingleton<AuthRepo>(
    () => AuthRepoImpl(
      getIt<AuthService>(),
      getIt<SupabaseCrudServices>(),
      getIt<SupabaseStorage>(),
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
}
