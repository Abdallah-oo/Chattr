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

final getIt = GetIt.instance;

void setUpGetIt() {
  // Services



   getIt.registerLazySingleton<SupabaseClientManager>(
    () => SupabaseClientManager(),
  );
    getIt.registerLazySingleton<AuthService>(
    () => AuthService(getIt<SupabaseClientManager>()),
  );

  getIt.registerLazySingleton<SupabaseCrudServices>(
    () => SupabaseCrudServices(getIt<SupabaseClientManager>())
  );

  getIt.registerLazySingleton<SupabaseStorage>(
    () => SupabaseStorage(storageFile: "users_image",clientManager: getIt<SupabaseClientManager>() ),
  );

  // Repositories
  getIt.registerLazySingleton<AuthRepo>(
    () => AuthRepoImpl(
      getIt<AuthService>(),
      getIt<SupabaseCrudServices>(),
      getIt<SupabaseStorage>(),
    ),

    
  );




  // Add ToContact
  getIt.registerLazySingleton<AddToContactsRepo>(
    () => AddToContactsRepoImpl(
      getIt<SupabaseClientManager>(),
      getIt<AuthService>(),
      getIt<SupabaseCrudServices>(),
    ),
  );
  //Fetch Contacts

    getIt.registerLazySingleton<FetchContactsRepo>(
    () => FetchContactsRepoImpl(
      getIt<SupabaseClientManager>(),
      getIt<SupabaseCrudServices>(),

    ),
  );

}
