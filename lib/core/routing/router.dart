import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger_clone0/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:messenger_clone0/core/routing/routes.dart';
import 'package:messenger_clone0/core/utils/di/get_it.dart';
import 'package:messenger_clone0/features/auth/data/repos/auth_repo.dart';
import 'package:messenger_clone0/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:messenger_clone0/features/auth/presentation/views/login_view/login_view.dart';
import 'package:messenger_clone0/features/auth/presentation/views/signup_view/signup_view.dart';

abstract class AppRouter {
  static final router = GoRouter(
    routes: [
      GoRoute(
        path: Routes.login,
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
    ],
  );
}
