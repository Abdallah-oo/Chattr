import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auto_login_state.dart';

class AutoLoginCubit extends Cubit<AutoLoginState> {
  final SupabaseClientManager _clientManager;
  final AuthRepo authRepo;
  AutoLoginCubit(this._clientManager, this.authRepo)
    : super(AutoLoginInitial());
  SupabaseClient get _client => _clientManager.client;
  Future<void> checkAutoLogin() async {
    emit(AutoLoginLoading());
    try {
      final session = _client.auth.currentSession;
      await authRepo.updateFCM();
      if (session != null) {
        emit(AutoLoginSuccess());
      } else {
        emit(AutoLoginFailure());
      }
    } catch (e) {
      emit(AutoLoginFailure());
    }
  }
}
