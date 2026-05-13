import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_auth_services.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/contacts/data/repos/fetch_contacts_repo/fetch_contacts_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'fetch_contacts_state.dart';

class FetchContactsCubit extends Cubit<FetchContactsState> {
  FetchContactsCubit(this._repo, this._auth) : super(FetchContactsInitial());

  final FetchContactsRepo _repo;
  final AuthService _auth;

  List<UserModel> contacts = [];
  RealtimeChannel? _channel;

  Future<void> fetchContacts() async {
    emit(FetchContactsLoading());

    try {
      final myId = _auth.currentUser!.id;

      // ===================== LOCAL (Hive) =====================
      final localResult = await _repo.getUsers();

      final localUsers = localResult.fold(
        (err) => <UserModel>[],
        (users) => users,
      );

      final localMe = localUsers.firstWhere(
        (u) => u.id == myId,
        orElse: () => UserModel(id: myId),
      );

      final contactIds = localMe.myContacts ?? [];

      if (contactIds.isNotEmpty) {
        contacts = localUsers.where((u) => contactIds.contains(u.id)).toList();

        emit(FetchContactsSuccess(contacts: contacts));
      }

      // ===================== REMOTE (Supabase - OPTIMIZED) =====================
      if (contactIds.isEmpty) {
        emit(FetchContactsSuccess(contacts: []));
        _subscribeToRealtime(myId);
        return;
      }

      final remoteResult = await _repo.fetchAllContacts(contactIds);

      final contactsList = remoteResult.fold(
        (err) => <UserModel>[],
        (data) => data.map((e) => UserModel.fromJson(e)).toList(),
      );

      await _repo.saveUsers(contactsList);

      contacts = contactsList;

      emit(FetchContactsSuccess(contacts: contacts));

      // ===================== REALTIME =====================
      _subscribeToRealtime(myId);
    } catch (e) {
      emit(FetchContactsFailure(errorMessage: e.toString()));
    }
  }

  void _subscribeToRealtime(String myId) {
    _channel?.unsubscribe();

    final channelResult = _repo.subscribeToUser(myId);

    channelResult.fold((err) => null, (channel) {
      _channel = channel;

      _channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messenger_users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: myId,
            ),
            callback: (payload) async {
              final updatedUser = UserModel.fromJson(payload.newRecord);

              await _repo.saveUser(updatedUser);

              final allUsersResult = await _repo.getUsers();

              final allUsers = allUsersResult.fold(
                (err) => <UserModel>[],
                (users) => users,
              );

              final newContacts = allUsers
                  .where((u) => (updatedUser.myContacts ?? []).contains(u.id))
                  .toList();

              if (_listsEqual(contacts, newContacts)) return;

              contacts = newContacts;
              emit(FetchContactsSuccess(contacts: contacts));
            },
          )
          .subscribe();
    });
  }

  bool _listsEqual(List<UserModel> a, List<UserModel> b) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }

    return true;
  }

  @override
  Future<void> close() {
    _channel?.unsubscribe();
    return super.close();
  }
}
