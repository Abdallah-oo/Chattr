import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_auth_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_crud_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';
import 'package:messenger_clone0/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo.dart';

class AddToContactsRepoImpl implements AddToContactsRepo {
  final SupabaseClientManager _clientManager;
  final SupabaseCrudServices _crud;
  final AuthService _auth;
  AddToContactsRepoImpl(this._clientManager, this._auth, this._crud);

  // add friend to your contatcs
  @override
  Future<Either<SupabaseError, UserModel>> addToContacts(String contactEmail) async {
    try {
      final myId = _auth.currentUser!.id;
      final client = _clientManager.client;
      // Get contact data
      final contactData = await _crud.getByFilter(
        table: 'messenger_users',
        filterColumn: 'email',
        filterValue: contactEmail,
      );

      if (contactData == null) {
        return left(const SupabaseError(message: 'User not found'));
      }

      final contact = UserModel.fromJson(contactData);

      if (contact.id == myId) {
        return left(const SupabaseError(message: 'You cannot add yourself'));
      }
      // Get my contacts
      final myData = await client
          .from('messenger_users')
          .select('my_contacts')
          .eq('id', myId)
          .single();

      final currentContacts =
          (myData['my_contacts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      // Prevent duplicate
      if (currentContacts.contains(contact.id)) {
        return left(const SupabaseError(message: 'Contact already added'));
      }

      // Append and update
      currentContacts.add(contact.id!);
      // Update my contacts
      await client
          .from('messenger_users')
          .update({'my_contacts': currentContacts})
          .eq('id', myId);

      return  Right(contact);
    } catch (e) {
      return left(SupabaseError(message: "$e"));
    }
  }


}
