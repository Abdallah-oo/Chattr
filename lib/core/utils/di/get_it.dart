import 'package:get_it/get_it.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_auth_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_crud_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_storage.dart';
import 'package:messenger_clone0/features/auth/data/repos/auth_repo.dart';
import 'package:messenger_clone0/features/auth/data/repos/auth_repo_impl.dart';

final getIt = GetIt.instance;

void setUpGetIt() {
  // Services
  getIt.registerLazySingleton<AuthService>(
    () => AuthService(SupabaseClientManager.client),
  );

  getIt.registerLazySingleton<SupabaseCrudServices>(
    () => SupabaseCrudServices(),
  );

  getIt.registerLazySingleton<SupabaseStorage>(
    () => SupabaseStorage(storageFile: "users_image"),
  );

  // Repositories
  getIt.registerLazySingleton<AuthRepo>(
    () => AuthRepoImpl(
      getIt<AuthService>(),
      getIt<SupabaseCrudServices>(),
      getIt<SupabaseStorage>(),
    ),
  );
}
