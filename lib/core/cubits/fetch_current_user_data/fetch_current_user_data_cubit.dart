import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_auth_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_crud_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
part 'fetch_current_user_data_state.dart';

class FetchCurrentUserDataCubit extends Cubit<FetchCurrentUserDataState>
    with WidgetsBindingObserver {
  FetchCurrentUserDataCubit({
    required AuthService auth,
    required SupabaseCrudServices crud,
    required this.client,
  }) : _auth = auth,
       _crud = crud,
       super(FetchCurrentUserDataInitial());

  final AuthService _auth;
  final SupabaseCrudServices _crud;
  final SupabaseClientManager client;
  SupabaseClient get _client => client.client;
  UserModel? currentUser;
  Timer? _heartbeatTimer;

  // ─────────────────────────────────────────────────────────────────
  // FETCH
  // ─────────────────────────────────────────────────────────────────

  Future<void> fetchCurruntUserData() async {
    emit(FetchCurrentUserDataLoading());
    try {
      final response = await _crud.getById(
        table: 'messenger_users',
        id: _auth.currentUser!.id,
      );

      currentUser = UserModel.fromJson(response);
      emit(FetchCurrentUserDataSuccess());
      // await NotificationService.instance.onUserLoggedIn();
      _initPresence();
    } on AuthException catch (e) {
      throw SupabaseError(message: e.message);
    } on SocketException {
      throw SupabaseError(message: 'No internet connection');
    } catch (e) {
      emit(FetchCurrentUserDataFailure(errorMessage: '$e'));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PRESENCE
  // ─────────────────────────────────────────────────────────────────

  void _initPresence() {
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    _startHeartbeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline(true);
        _startHeartbeat();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // شيلنا inactive عشان بيحصل من غير ما الـ app يروح الخلفية فعلاً
        _setOnline(false);
        _stopHeartbeat();
        break;
      default:
        break;
    }
  }

  Future<void> _setOnline(bool isOnline) async {
    final id = _auth.currentUser?.id;
    if (id == null) return;

    try {
      await _client
          .from('messenger_users')
          .update({
            'is_online': isOnline,
            'last_seen': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      debugPrint('❌ _setOnline: $e');
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _setOnline(true),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ─────────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────────

  @override
  Future<void> close() async {
    _stopHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    await _setOnline(false); // await عشان يخلص قبل الـ dispose
    return super.close();
  }
}
