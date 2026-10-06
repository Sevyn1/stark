import 'dart:typed_data';
import '../repositories/conversation_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:stark/utils/snack_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stark/core/providers/message_reply_provider.dart';
import 'package:stark/core/providers/storage_repository_provider.dart';
import 'package:stark/features/auth/controllers/auth_controller.dart';
import 'package:stark/features/messaging/repositories/messaging_repository.dart';
import 'package:stark/features/organisation/controllers/organisation_controller.dart';
import 'package:stark/models/message_model.dart';

//! get messages stream provider
final getGroupChatStreamProvider = StreamProvider.autoDispose((ref) {
  final user = ref.watch(userProvider);
  final room = ref.watch(activeConversationProvider);
  if (user == null || user.organisation.isEmpty)
    return Stream.value(<MessageModel>[]);
  return ref
      .watch(messagingRepositoryProvider)
      .getGroupChatStream(user.organisation, conversationId: room?.id);
});

//! the messaging controller provider
final messagingControllerProvider =
    StateNotifierProvider<MessagingController, bool>((ref) {
      ref.watch(userProvider);
      final messagingRepository = ref.watch(messagingRepositoryProvider);
      final storageRepository = ref.watch(storageRepositoryProvider);
      return MessagingController(
        messagingRepository: messagingRepository,
        storageRepository: storageRepository,
        ref: ref,
      );
    });

//! messaging state notifier
class MessagingController extends StateNotifier<bool> {
  final MessagingRepository _messagingRepository;
  final StorageRepository _storageRepository;
  final Ref _ref;
  MessagingController({
    required MessagingRepository messagingRepository,
    required StorageRepository storageRepository,
    required Ref ref,
  }) : _messagingRepository = messagingRepository,
       _storageRepository = storageRepository,
       _ref = ref,
       super(false);

  //! get message streams
  Stream<List<MessageModel>> getGroupChatStream() {
    final user = _ref.read(userProvider)!;
    return _messagingRepository.getGroupChatStream(user.organisation);
  }

  //! send text message (manager)
  Future<bool> sendTextMessage({
    required BuildContext context,
    required String text,
  }) async {
    final messageReply = _ref.read(messageReplyProvider);
    final user = _ref.read(userProvider)!;
    final room = _ref.read(activeConversationProvider);
    state = true;

    final result = await _messagingRepository.sendTextMessage(
      text: text,
      orgName: user.organisation,
      conversationId: room?.id,
      senderUserName: '${user.firstName} ${user.lastName}',
      messageReply: messageReply,
      senderProfilePic: user.profilePic,
    );

    if (mounted) state = false;
    return result.fold(
      (failure) {
        if (context.mounted) showSnackBar(context, failure.message);
        return false;
      },
      (_) {
        if (mounted) {
          final key = room?.id ?? 'team:${user.organisation}';
          final drafts = {..._ref.read(chatDraftsProvider)};
          if (drafts[key]?.trim() == text.trim()) {
            drafts.remove(key);
            _ref.read(chatDraftsProvider.notifier).state = drafts;
          }
        }
        if (mounted && _ref.read(activeConversationProvider)?.id == room?.id)
          _ref.read(messageReplyProvider.notifier).state = null;
        return true;
      },
    );
  }

  Future<bool> sendImage({
    required BuildContext context,
    required Uint8List bytes,
  }) async {
    final user = _ref.read(userProvider)!;
    final room = _ref.read(activeConversationProvider);
    if (user.organisation.isEmpty) {
      showSnackBar(context, 'Join an organisation before messaging.');
      return false;
    }
    final upload = await _storageRepository.storeFile(
      path: 'chat/${Uri.encodeComponent(user.organisation)}',
      id: const Uuid().v4(),
      file: null,
      webFile: bytes,
    );
    return upload.fold<Future<bool>>(
      (failure) async {
        if (context.mounted) showSnackBar(context, failure.message);
        return false;
      },
      (url) async {
        final sent = await _messagingRepository.sendImageMessage(
          url: url,
          orgName: user.organisation,
          senderUsername: '${user.firstName} ${user.lastName}',
          senderProfilePic: user.profilePic,
          conversationId: room?.id,
        );
        return sent.fold((failure) {
          if (context.mounted) showSnackBar(context, failure.message);
          return false;
        }, (_) => true);
      },
    );
  }
}
