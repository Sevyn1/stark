import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:stark/core/constants/firebase_constants.dart';
import 'package:stark/core/failure.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/core/type_defs.dart';
import 'package:stark/models/invite_model.dart';
import 'package:stark/models/user_model.dart';

//! the provider for the employees repo
final employeeRepositoryProvider = Provider((ref) {
  return EmployeeRepository(firestore: ref.watch(firestoreProvider));
});

//! the employee repository class handling everything related to employees
class EmployeeRepository {
  final FirebaseFirestore _firestore;
  EmployeeRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  //! send invitation to employee
  FutureVoid sendInvite(InviteModel invite, String orgName) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final orgRef = _organisations.doc(orgName);
        final inviteRef = _invites.doc(invite.receiverId);
        final org = await transaction.get(orgRef);
        final employee = await transaction.get(
          _firestore.collection('employeeDirectory').doc(invite.receiverId),
        );
        final current = await transaction.get(inviteRef);
        final orgData = org.data() as Map<String, dynamic>?;
        final profile = employee.data() as Map<String, dynamic>?;
        if (!org.exists ||
            !(orgData?['managers'] as List? ?? []).contains(invite.managerId))
          throw StateError(
            'Only this organisation’s manager can invite employees.',
          );
        if (!employee.exists ||
            profile?['isAdmin'] != false ||
            (profile?['organisation'] ?? '') != '')
          throw StateError(
            'Choose an employee who has not joined another organisation.',
          );
        if (current.exists &&
            (current.data() as Map<String, dynamic>)['status'] == 'pending')
          throw StateError('This employee already has a pending invitation.');
        transaction.update(orgRef, {
          'prospectiveEmployees': FieldValue.arrayUnion([invite.receiverId]),
        });
        transaction.set(inviteRef, invite.toMap());
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  //! get stream of invites for manager
  Stream<List<InviteModel>> getInvitesForManager({required String managerId}) {
    return _invites
        .where('managerId', isEqualTo: managerId)
        // .orderBy('actionAt', descending: true)
        .snapshots()
        .map(
          (event) => event.docs
              .map((e) => InviteModel.fromMap(e.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  //! get particular invite model
  Stream<InviteModel> getInViteModel({required String receiverId}) {
    return _invites
        .doc(receiverId)
        .snapshots()
        .map(
          (event) => InviteModel.fromMap(event.data() as Map<String, dynamic>),
        );
  }

  //! get stream of invites for employee
  Stream<List<InviteModel>> getInvitesForEmployee({
    required String employeeId,
  }) {
    return _invites
        .where('receiverId', isEqualTo: employeeId)
        // .orderBy('actionAt', descending: true)
        .snapshots()
        .map(
          (event) => event.docs
              .map((e) => InviteModel.fromMap(e.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  //! reject invitaion
  FutureVoid rejectInvite(InviteModel invite) async {
    try {
      final batch = _firestore.batch();
      batch.update(_organisations.doc(invite.organisationName), {
        'prospectiveEmployees': FieldValue.arrayRemove([invite.receiverId]),
      });
      batch.delete(_invites.doc(invite.receiverId));
      await batch.commit();
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid acceptInvite(InviteModel invite) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final inviteRef = _invites.doc(invite.receiverId);
        final userRef = _users.doc(invite.receiverId);
        final stored = await transaction.get(inviteRef);
        final user = await transaction.get(userRef);
        final data = stored.data() as Map<String, dynamic>?;
        final profile = user.data() as Map<String, dynamic>?;
        if (!stored.exists ||
            data?['organisationName'] != invite.organisationName)
          throw StateError('Invitation no longer exists.');
        if (data?['status'] == 'accepted') return;
        if (data?['status'] != 'pending' ||
            !user.exists ||
            (profile?['organisation'] ?? '') != '')
          throw StateError('Invitation can no longer be accepted.');
        transaction.update(inviteRef, {
          'status': 'accepted',
          'actionAt': DateTime.now().millisecondsSinceEpoch,
        });
        transaction.update(userRef, {'organisation': invite.organisationName});
        transaction.delete(
          _firestore.collection('employeeDirectory').doc(invite.receiverId),
        );
        transaction.set(_messageGroup.doc(invite.organisationName), {
          'membersUid': FieldValue.arrayUnion([invite.receiverId]),
        }, SetOptions(merge: true));
        transaction.update(_organisations.doc(invite.organisationName), {
          'prospectiveEmployees': FieldValue.arrayRemove([invite.receiverId]),
          'employees': FieldValue.arrayUnion([invite.receiverId]),
        });
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  //! stream of employees
  Stream<List<UserModel>> getEmployees(String orgName) {
    return _users
        .where('organisation', isEqualTo: orgName)
        .where('isAdmin', isEqualTo: false)
        .snapshots()
        .map((event) {
          List<UserModel> employees = [];
          for (var employee in event.docs) {
            employees.add(
              UserModel.fromMap(employee.data() as Map<String, dynamic>),
            );
          }
          log(employees.length.toString());
          return employees;
        });
  }

  //! search for employees
  Stream<List<UserModel>> searchForEmployeesToInvite(String query) {
    final prefix = query.trim().toLowerCase();
    Query users = _firestore
        .collection('employeeDirectory')
        .where('isAdmin', isEqualTo: false)
        .where('organisation', isEqualTo: '');
    if (prefix.isNotEmpty)
      users = users.where(
        'email',
        isGreaterThanOrEqualTo: prefix,
        isLessThanOrEqualTo: '$prefix\uf8ff',
      );
    return users.snapshots().map(
      (event) => event.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList(),
    );
  }

  CollectionReference get _invites =>
      _firestore.collection(FirebaseConstants.invitesCollection);

  CollectionReference get _organisations =>
      _firestore.collection(FirebaseConstants.organisationsCollection);

  CollectionReference get _users =>
      _firestore.collection(FirebaseConstants.usersCollection);

  CollectionReference get _messageGroup =>
      _firestore.collection(FirebaseConstants.messageGroupCollection);
}
