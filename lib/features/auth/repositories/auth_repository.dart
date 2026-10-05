import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:stark/core/constants/constants.dart';
import 'package:stark/core/constants/firebase_constants.dart';
import 'package:stark/core/failure.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/core/type_defs.dart';
import 'package:stark/models/user_model.dart';
import 'package:uuid/uuid.dart';

//! provider for the auth repo
final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    firestore: ref.read(firestoreProvider),
    auth: ref.read(authProvider),
  ),
);

//! auth repo where all the auth magic happens
class AuthRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AuthRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _auth = auth,
       _firestore = firestore;

  //! to sign up admin
  FutureEither<UserModel> signUpAdmin({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required bool isAdmin,
  }) async {
    try {
      UserCredential userCredential;

      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      UserModel userModel;

      if (userCredential.additionalUserInfo?.isNewUser ?? true) {
        userModel = UserModel(
          uid: userCredential.user!.uid,
          firstName: firstName,
          lastName: lastName,
          profilePic: '',
          email: userCredential.user!.email ?? email,
          isAdmin: isAdmin,
          organisation: '',
          role: '',
          phone: '',
        );
        try {
          final batch = _firestore.batch();
          batch.set(_users.doc(userModel.uid), userModel.toMap());
          if (!isAdmin)
            batch.set(
              _firestore.collection('employeeDirectory').doc(userModel.uid),
              {
                'uid': userModel.uid,
                'firstName': userModel.firstName,
                'lastName': userModel.lastName,
                'email': userModel.email,
                'isAdmin': false,
                'organisation': '',
              },
            );
          await batch.commit();
        } catch (_) {
          // Roll back only the newly-created account if its profile cannot save.
          await userCredential.user!.delete();
          rethrow;
        }
      } else {
        return left(Failure('These credentials have been used!'));
      }

      return right(userModel);
    } on FirebaseException catch (e) {
      return left(Failure(e.toString()));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  //! to login admin
  FutureEither<UserModel> logInAdmin({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      UserModel userModel = await getUserData(userCredential.user!.uid).first;

      return right(userModel);
    } on FirebaseException catch (e) {
      return left(Failure(e.toString()));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  Stream<UserModel> getUserData(String uid) {
    return _users
        .doc(uid)
        .snapshots()
        .map(
          (event) => event.exists
              ? UserModel.fromMap({
                  ...event.data() as Map<String, dynamic>,
                  'uid': uid,
                })
              : throw StateError('Profile not found'),
        );
  }

  Future<void> logOut() async {
    await _auth.signOut();
  }

  Stream<User?> get authStateChange => _auth.authStateChanges();

  CollectionReference get _users =>
      _firestore.collection(FirebaseConstants.usersCollection);
}
