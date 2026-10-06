import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/providers/firebase_provider.dart';
import '../../../models/user_model.dart';

class ConversationTarget {
  final String id, name, otherUid;
  const ConversationTarget({
    required this.id,
    required this.name,
    required this.otherUid,
  });
}

final activeConversationProvider = StateProvider<ConversationTarget?>((ref) {
  ref.watch(userProvider.select((u) => (u?.uid, u?.organisation)));
  return null;
});
final workspacePeopleProvider = StreamProvider.autoDispose<List<UserModel>>((
  ref,
) {
  final user = ref.watch(userProvider);
  if (user == null || user.organisation.isEmpty) return Stream.value([]);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .where('organisation', isEqualTo: user.organisation)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => UserModel.fromMap({...d.data(), 'uid': d.id}))
            .toList(),
      );
});
final conversationRepositoryProvider = Provider(
  (ref) => ConversationRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(authProvider),
  ),
);

class ConversationRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  ConversationRepository({required this.firestore, required this.auth});
  Future<ConversationTarget> open(UserModel other, String org) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || uid == other.uid || org.isEmpty)
      throw StateError('Choose another person in your workspace.');
    final members = [uid, other.uid]..sort();
    final id = '$org::${members.join('::')}';
    await firestore.runTransaction((t) async {
      final me = await t.get(firestore.collection('users').doc(uid));
      final teammate = await t.get(
        firestore.collection('users').doc(other.uid),
      );
      final target = firestore.collection('directConversations').doc(id);
      final existing = await t.get(target);
      if (me.data()?['organisation'] != org ||
          teammate.data()?['organisation'] != org)
        throw StateError('You can message people in your workspace.');
      if (existing.exists) {
        final storedMembers = List<String>.from(
          existing.data()?['participantIds'] ?? [],
        )..sort();
        if (storedMembers.join('::') != members.join('::'))
          throw StateError(
            'This conversation does not match the selected teammate.',
          );
        if (existing.data()?['organisationName'] != org ||
            !(List<String>.from(
              existing.data()?['participantIds'] ?? [],
            )).contains(uid))
          throw StateError('This conversation is unavailable.');
        return;
      }
      t.set(target, {
        'organisationName': org,
        'participantIds': members,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return ConversationTarget(
      id: id,
      name: '${other.firstName} ${other.lastName}',
      otherUid: other.uid,
    );
  }
}

final chatDraftsProvider = StateProvider<Map<String, String>>((ref) {
  ref.watch(userProvider.select((u) => (u?.uid, u?.organisation)));
  return {};
});
