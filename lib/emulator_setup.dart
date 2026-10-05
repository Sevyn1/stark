import 'package:stark/core/providers/firebase_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const demoPassword =
    'StarkDemo123!'; // Public fixture password; local emulator only.
const demoManagerEmail = 'alex.manager@example.test';
const demoEmployeeEmail = 'jamie.employee@example.test';

/// Fictional accounts in a demo- project, usable through normal login and logout.
Future<void> seedLocalDemo() async {
  final auth = authService;
  final db = firestoreService;
  Future<String> account(String email) async {
    try {
      return (await auth.signInWithEmailAndPassword(
              email: email, password: demoPassword))
          .user!
          .uid;
    } on FirebaseAuthException catch (e) {
      if (!['user-not-found', 'invalid-credential', 'invalid-login-credentials']
          .contains(e.code)) rethrow;
      return (await auth.createUserWithEmailAndPassword(
              email: email, password: demoPassword))
          .user!
          .uid;
    }
  }

  final manager = await account(demoManagerEmail);
  final jamie = await account(demoEmployeeEmail);
  final taylor = await account('taylor.employee@example.test');
  final sam = await account('sam.invitee@example.test');
  final orgRef = db.collection('organisations').doc('Stark Demo Studio');
  final existingOrg = await orgRef.get();
  final batch = db.batch();
  Future<void> profile(
      String uid, String first, String last, String email, bool admin, {String organisation = 'Stark Demo Studio'}) async {
    final ref = db.collection('users').doc(uid);
    if ((await ref.get()).exists) return;
    batch.set(ref, {
      'uid': uid,
      'firstName': first,
      'lastName': last,
      'email': email,
      'profilePic': '',
      'isAdmin': admin,
      'organisation': organisation,
      'role': admin ? 'Manager' : 'Developer',
      'phone': ''
    });
  }

  await profile(manager, 'Alex', 'Morgan', demoManagerEmail, true);
  await profile(jamie, 'Jamie', 'Lee', demoEmployeeEmail, false);
  await profile(
      taylor, 'Taylor', 'Rivera', 'taylor.employee@example.test', false);
  await profile(sam, 'Sam', 'Reed', 'sam.invitee@example.test', false, organisation: '');
  if (!existingOrg.exists) {
    batch.set(orgRef, {
      'id': 'stark-demo',
      'name': 'Stark Demo Studio',
      'avatar': '',
      'description': 'Fictional local employee-management workspace',
      'managers': [manager],
      'employees': [jamie, taylor],
      'prospectiveEmployees': [],
      'fixtureVersion': 2
    });
  } else if (existingOrg.data()?['fixtureVersion'] != 2) {
    // Migrate only the two known placeholder employees from the initial preview.
    batch.delete(db.collection('users').doc('demo-jamie'));
    batch.delete(db.collection('users').doc('demo-taylor'));
    batch.update(orgRef, {
      'managers': [manager],
      'employees': [jamie, taylor],
      'fixtureVersion': 2
    });
  }
  final projectRef = db.collection('projects').doc(
      '${Uri.encodeComponent('Stark Demo Studio')}::${Uri.encodeComponent('Customer Portal')}');
  final taskRef = db.collection('tasks').doc(
      '${Uri.encodeComponent('Stark Demo Studio')}::${Uri.encodeComponent('Review API validation')}');
  final project = await projectRef.get();
  final now = DateTime.now();
  // Retire only the two original preview records after moving to scoped IDs.
  batch.delete(db.collection('projects').doc('Customer Portal'));
  batch.delete(db.collection('tasks').doc('Review API validation'));
  if (!project.exists || existingOrg.data()?['fixtureVersion'] != 2) {
    batch.set(projectRef, {
      'organisationName': 'Stark Demo Studio',
      'managerId': manager,
      'name': 'Customer Portal',
      'employeeIds': [jamie, taylor],
      'taskIds': ['Review API validation'],
      'status': 'ongoing',
      'type': 'Development',
      'startDateTime':
          now.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
      'endDateTime': now.add(const Duration(days: 14)).millisecondsSinceEpoch
    });
    batch.set(taskRef, {
      'taskName': 'Review API validation',
      'projectName': 'Customer Portal',
      'employeeId': jamie,
      'description': 'Check request validation and error handling.',
      'organisationName': 'Stark Demo Studio',
      'status': 'ongoing',
      'managerId': manager
    });
  }
  batch.set(
      db.collection('messageGroup').doc('Stark Demo Studio'),
      {
        'senderId': manager,
        'name': 'Stark Demo Studio',
        'groupId': 'Stark Demo Studio',
        'lastMessage': '',
        'groupPic': '',
        'membersUid': FieldValue.arrayUnion([manager, jamie, taylor]),
        'timeSent': now.millisecondsSinceEpoch,
      },
      SetOptions(merge: true));
  await batch.commit();
  await auth.signInWithEmailAndPassword(
      email: demoManagerEmail, password: demoPassword);
}
