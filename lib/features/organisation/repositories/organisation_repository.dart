import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:stark/core/constants/firebase_constants.dart';
import 'package:stark/core/failure.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/core/type_defs.dart';
import 'package:stark/models/org_message_model.dart';
import 'package:stark/models/organisation_model.dart';
import 'package:stark/models/user_model.dart';

import '../../../models/attemdance_model.dart';

//! the organisation repo provider
final organisationsRepositoryProvider = Provider((ref) {
  return OrganisationsRepository(firestore: ref.watch(firestoreProvider));
});

//! org repo
class OrganisationsRepository {
  final FirebaseFirestore _firestore;
  OrganisationsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  //! create organisation
  FutureVoid createOrganisation(OrganisationModel organisation, String uid,
      {OrgMessagingModel? messaging}) async {
    try {
      if (organisation.name.trim().isEmpty || organisation.name.contains('/')) {
        throw ArgumentError('Enter a valid organisation name.');
      }
      final reference = _organisations.doc(organisation.name);
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reference);
        final user = await transaction.get(_users.doc(uid));
        if (existing.exists)
          throw StateError('Organisation with the same name exists');
        if (!user.exists) throw StateError('Manager profile does not exist');
        final profile = user.data() as Map<String, dynamic>;
        if (profile['isAdmin'] != true) throw StateError('A manager account is required.');
        if ((profile['organisation'] ?? '') != '') throw StateError('Your account already has a workspace.');
        transaction.set(reference, organisation.toMap());
        transaction
            .update(_users.doc(uid), {'organisation': organisation.name});
        if (messaging != null)
          transaction.set(
              _messageGroup.doc(organisation.name), messaging.toMap());
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  //! create message group
  FutureVoid createMessageGroup(OrgMessagingModel orgMessaging) async {
    try {
      var orgMessagingDoc = await _messageGroup.doc(orgMessaging.name).get();
      if (orgMessagingDoc.exists) {
        throw 'Group with the same name exists';
      }

      await _messageGroup.doc(orgMessaging.name).set(orgMessaging.toMap());
      return right(null);
    } on FirebaseException catch (e) {
      return left(Failure(e.message ?? e.code));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  //! get org messaging group

  //! get managers organisations
  Stream<List<OrganisationModel>> getManagerOrganisations(String uid) {
    return _organisations.where('managers', arrayContains: uid).snapshots().map(
      (event) {
        List<OrganisationModel> organisations = [];
        for (var doc in event.docs) {
          organisations.add(
              OrganisationModel.fromMap(doc.data() as Map<String, dynamic>));
        }
        return organisations;
      },
    );
  }

  //! get employees organisations
  Stream<List<OrganisationModel>> getEmployeeOrganisations(String uid) {
    return _organisations
        .where('employees', arrayContains: uid)
        .snapshots()
        .map(
      (event) {
        List<OrganisationModel> organisations = [];
        for (var doc in event.docs) {
          organisations.add(
              OrganisationModel.fromMap(doc.data() as Map<String, dynamic>));
        }
        return organisations;
      },
    );
  }

  //! sack employee
  FutureVoid sackEmployee({
    required String organisationName,
    required String employeeId,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_invites.doc(employeeId));
      batch.update(_organisations.doc(organisationName), {
        'employees': FieldValue.arrayRemove([employeeId]),
        'prospectiveEmployees': FieldValue.arrayRemove([employeeId]),
      });
      batch.update(_users.doc(employeeId), {'organisation': ''});
      batch.set(
          _messageGroup.doc(organisationName),
          {
            'membersUid': FieldValue.arrayRemove([employeeId]),
          },
          SetOptions(merge: true));
      await batch.commit();
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  //! get organisation
  Stream<OrganisationModel> getOrganisationByName(String name) {
    return _organisations.doc(name).snapshots().map((event) =>
        OrganisationModel.fromMap(event.data() as Map<String, dynamic>));
  }

  //! search for employees
  Stream<List<UserModel>> searchForEmployees(String query) {
    final prefix = query.trim().toLowerCase();
    Query users = _users.where('isAdmin', isEqualTo: false);
    if (prefix.isNotEmpty)
      users = users.where('email',
          isGreaterThanOrEqualTo: prefix, isLessThanOrEqualTo: '$prefix\uf8ff');
    return users.snapshots().map((event) => event.docs
        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList());
  }

  // //
  CollectionReference get _organisations =>
      _firestore.collection(FirebaseConstants.organisationsCollection);

  CollectionReference get _invites =>
      _firestore.collection(FirebaseConstants.invitesCollection);

  CollectionReference get _users =>
      _firestore.collection(FirebaseConstants.usersCollection);

  CollectionReference get _messageGroup =>
      _firestore.collection(FirebaseConstants.messageGroupCollection);
}
