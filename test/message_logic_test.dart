import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:stark/features/messaging/repositories/messaging_repository.dart';

class LocalUser extends Fake implements User {
  @override
  String get uid => 'sender';
}

class LocalAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => LocalUser();
}

void main() {
  test('Text message is stored before success and whitespace is rejected',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = MessagingRepository(firestore: db, auth: LocalAuth());
    expect(
        (await repo.sendTextMessage(
                text: '  Hello team  ',
                orgName: 'Demo',
                senderUserName: 'Alex',
                messageReply: null,
                senderProfilePic: ''))
            .isRight(),
        true);
    final messages = await repo.getGroupChatStream('Demo').first;
    expect(messages.single.text, 'Hello team');
    expect(messages.single.senderId, 'sender');
    expect(
        (await repo.sendTextMessage(
                text: ' ',
                orgName: 'Demo',
                senderUserName: 'Alex',
                messageReply: null,
                senderProfilePic: ''))
            .isLeft(),
        true);
    expect((await repo.getGroupChatStream('Demo').first).length, 1);
  });
  test('Image records retain image type and destination organisation',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = MessagingRepository(firestore: db, auth: LocalAuth());
    expect(
        (await repo.sendImageMessage(
                url: 'http://127.0.0.1:9199/test.png',
                orgName: 'Demo',
                senderUsername: 'Alex',
                senderProfilePic: ''))
            .isRight(),
        true);
    final messages = await repo.getGroupChatStream('Demo').first;
    expect(messages.single.type.name, 'image');
    expect((await repo.getGroupChatStream('Other').first), isEmpty);
  });
}
