import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:stark/core/constants/firebase_constants.dart';
import 'package:stark/core/enums/enums.dart';
import 'package:stark/core/failure.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/core/providers/message_reply_provider.dart';
import 'package:stark/core/type_defs.dart';
import 'package:stark/models/message_model.dart';
import 'package:stark/models/user_model.dart';
import 'package:uuid/uuid.dart';

//! the organisation repo provider
final messagingRepositoryProvider = Provider((ref) {
  return MessagingRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.read(authProvider),
  );
});

class MessagingRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  MessagingRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _auth = auth,
        _firestore = firestore;

  //! get messages stream
  Stream<List<MessageModel>> getGroupChatStream(String orgName) {
    return _firestore
        .collection('messageGroup')
        .doc(orgName)
        .collection('messages')
        .orderBy('timeSent')
        .snapshots()
        .map((event) {
      List<MessageModel> messages = [];
      for (var document in event.docs) {
        messages.add(MessageModel.fromMap(document.data()));
      }
      return messages;
    });
  }

  // send text message
  FutureVoid sendTextMessage({
    required String text,
    required String orgName,
    required String senderUserName,
    required MessageReply? messageReply,
    required String senderProfilePic,
  }) async {
    try {
      if (text.trim().isEmpty) throw ArgumentError('Enter a message.');
      if (orgName.isEmpty || _auth.currentUser == null)
        throw StateError('Join an organisation before messaging.');
      var timeSent = DateTime.now();
      var messageId = const Uuid().v1();

      await _saveMessageToMessageSubcollection(
        orgName: orgName,
        text: text.trim(),
        timeSent: timeSent,
        messageId: messageId,
        messageType: MessageEnum.text,
        messageReply: messageReply,
        senderUsername: senderUserName,
        recieverUserName: orgName,
        senderProfilePic: senderProfilePic,
      );
      return right(null);
    } on FirebaseException catch (e) {
      return left(Failure(e.message ?? e.code));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid sendImageMessage(
      {required String url,
      required String orgName,
      required String senderUsername,
      required String senderProfilePic}) async {
    try {
      if (orgName.isEmpty || _auth.currentUser == null)
        throw StateError('Join an organisation before messaging.');
      await _saveMessageToMessageSubcollection(
          orgName: orgName,
          text: url,
          timeSent: DateTime.now(),
          messageId: const Uuid().v4(),
          messageType: MessageEnum.image,
          messageReply: null,
          senderUsername: senderUsername,
          recieverUserName: orgName,
          senderProfilePic: senderProfilePic);
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  Future<void> _saveMessageToMessageSubcollection({
    required String orgName,
    required String text,
    required DateTime timeSent,
    required String messageId,
    required String senderProfilePic,
    required MessageEnum messageType,
    required MessageReply? messageReply,
    required String senderUsername,
    required String? recieverUserName,
  }) async {
    final message = MessageModel(
      senderProfilePic: senderProfilePic,
      senderUsername: senderUsername,
      senderId: _auth.currentUser!.uid,
      recieverid: orgName,
      text: text,
      type: messageType,
      timeSent: timeSent,
      messageId: messageId,
      isSeen: false,
      repliedMessage: messageReply == null ? '' : messageReply.message,
      repliedTo: messageReply == null
          ? ''
          : messageReply.isMe
              ? senderUsername
              : recieverUserName ?? '',
      repliedMessageType:
          messageReply == null ? MessageEnum.text : messageReply.messageEnum,
    );

    await _firestore
        .collection('messageGroup')
        .doc(orgName)
        .collection('messages')
        .doc(messageId)
        .set(
          message.toMap(),
        );
  }

  CollectionReference get _messageGroup =>
      _firestore.collection(FirebaseConstants.messageGroupCollection);
}
