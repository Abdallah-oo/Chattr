import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'add_to_contacts_state.dart';

class AddToContactsCubit extends Cubit<AddToContactsState> {
  AddToContactsCubit(this._contactsRepo) : super(AddToContactsInitial());
  final AddToContactsRepo _contactsRepo;

  Future<void> addContact(String contactEmail) async {
    emit(AddToContactsLoading());
    final result = await _contactsRepo.addToContacts(contactEmail);
    result.fold(
      (l) => emit(AddToContactsFailure(errorMessage: l.message)),
      (r) => emit(AddToContactsSuccess(contact: r)),
    );
  }
}
