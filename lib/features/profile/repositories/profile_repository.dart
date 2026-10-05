import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:stark/core/constants/firebase_constants.dart';
import 'package:stark/core/failure.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/core/type_defs.dart';
import 'package:stark/models/user_model.dart';

final userProfileRepositoryProvider = Provider((ref) {
  return UserProfileRepository(firestore: ref.watch(firestoreProvider));
});

class UserProfileRepository {
  final FirebaseFirestore _firestore;
  UserProfileRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  FutureVoid editProfile(UserModel user) async {
    try {
      final reference = _users.doc(user.uid);
      final snapshot = await reference.get();
      final original = snapshot.data() as Map<String, dynamic>;
      final batch = _firestore.batch();
      batch.update(reference, {
        'firstName': user.firstName.trim(),
        'lastName': user.lastName.trim(),
        'phone': user.phone.trim(),
        'profilePic': user.profilePic,
        'role': user.role.trim(),
      });
      if (original['isAdmin'] == false && original['organisation'] == '')
        batch.set(_firestore.collection('employeeDirectory').doc(user.uid), {
          'uid': user.uid,
          'firstName': user.firstName.trim(),
          'lastName': user.lastName.trim(),
          'email': original['email'],
          'isAdmin': false,
          'organisation': '',
        });
      await batch.commit();
      return right(null);
    } on FirebaseException catch (e) {
      return left(Failure(e.message ?? e.code));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  CollectionReference get _users =>
      _firestore.collection(FirebaseConstants.usersCollection);
}
