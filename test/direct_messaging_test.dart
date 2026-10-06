import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/features/auth/controllers/auth_controller.dart';
import 'package:stark/features/messaging/repositories/conversation_repository.dart';
import 'package:stark/features/messaging/repositories/messaging_repository.dart';
import 'package:stark/features/messaging/views/messaging_view.dart';
import 'package:stark/models/user_model.dart';

class MessageUser extends Fake implements User {
  final String id;
  MessageUser(this.id);
  @override
  String get uid => id;
}

class MessageAuth extends Fake implements FirebaseAuth {
  final String uid;
  MessageAuth(this.uid);
  @override
  User? get currentUser => MessageUser(uid);
}

UserModel person(
  String uid,
  String first, {
  String org = 'Demo',
  bool manager = false,
}) => UserModel(
  uid: uid,
  firstName: first,
  lastName: 'Test',
  email: '$uid@example.test',
  isAdmin: manager,
  organisation: org,
  role: 'Developer',
  phone: '',
  profilePic: '',
);
Future<FakeFirebaseFirestore> people() async {
  final db = FakeFirebaseFirestore();
  for (final u in [
    person('sender', 'Jamie'),
    person('receiver', 'Alex', manager: true),
    person('outside', 'Someone', org: 'Other'),
  ]) {
    await db.collection('users').doc(u.uid).set(u.toMap());
  }
  return db;
}

void main() {
  test('Both participants reuse the same direct conversation', () async {
    final db = await people();
    final employee = ConversationRepository(
      firestore: db,
      auth: MessageAuth('sender'),
    );
    final room = await employee.open(person('receiver', 'Alex'), 'Demo');
    final manager = ConversationRepository(
      firestore: db,
      auth: MessageAuth('receiver'),
    );
    final same = await manager.open(person('sender', 'Jamie'), 'Demo');
    expect(room.id, same.id);
    expect((await db.collection('directConversations').get()).docs.length, 1);
  });
  test(
    'Direct conversation rejects self, outside workspace and mismatched participants',
    () async {
      final db = await people();
      final repo = ConversationRepository(
        firestore: db,
        auth: MessageAuth('sender'),
      );
      await expectLater(
        repo.open(person('sender', 'Jamie'), 'Demo'),
        throwsStateError,
      );
      await expectLater(
        repo.open(person('outside', 'Someone', org: 'Other'), 'Demo'),
        throwsStateError,
      );
      await db
          .collection('directConversations')
          .doc('Demo::receiver::sender')
          .set({
            'organisationName': 'Demo',
            'participantIds': ['outside', 'sender'],
          });
      await expectLater(
        repo.open(person('receiver', 'Alex'), 'Demo'),
        throwsStateError,
      );
    },
  );
  test(
    'A direct message appears in the private room and not the team chat',
    () async {
      final db = await people();
      final repo = MessagingRepository(
        firestore: db,
        auth: MessageAuth('sender'),
      );
      final room = await ConversationRepository(
        firestore: db,
        auth: MessageAuth('sender'),
      ).open(person('receiver', 'Alex'), 'Demo');
      final result = await repo.sendTextMessage(
        text: 'Hello Alex',
        orgName: 'Demo',
        conversationId: room.id,
        senderUserName: 'Jamie Test',
        messageReply: null,
        senderProfilePic: '',
      );
      expect(result.isRight(), true);
      final messages = await repo
          .getGroupChatStream('Demo', conversationId: room.id)
          .first;
      expect(messages.single.text, 'Hello Alex');
      expect(messages.single.recieverid, room.id);
      expect(await repo.getGroupChatStream('Demo').first, isEmpty);
    },
  );
  testWidgets(
    'People search opens a teammate conversation with a visible composer',
    (tester) async {
      final db = await people();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(db),
            authProvider.overrideWithValue(MessageAuth('sender')),
            userProvider.overrideWith((ref) => person('sender', 'Jamie')),
          ],
          child: const MaterialApp(home: Scaffold(body: MessagingView())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Search teammates'), findsOneWidget);
      expect(find.text('Alex Test'), findsOneWidget);
      expect(find.text('Someone Test'), findsNothing);
      await tester.enterText(find.byType(TextField), 'alex');
      await tester.pump();
      await tester.tap(find.text('Alex Test'));
      await tester.pumpAndSettle();
      expect(find.text('Private conversation'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Hello Alex');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Hello Alex'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Unsent private draft');
      await tester.tap(find.byTooltip('Back to people'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Team chat'));
      await tester.pumpAndSettle();
      expect(find.text('Hello Alex'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Separate team draft');
      await tester.tap(find.byTooltip('Back to people'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alex Test'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Unsent private draft',
      );
      expect(find.text('Hello Alex'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
