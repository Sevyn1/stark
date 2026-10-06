import 'package:stark/core/providers/firebase_provider.dart';
import '../repositories/conversation_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stark/core/providers/message_reply_provider.dart';
import 'package:stark/features/messaging/controllers/messaging_controller.dart';
import 'package:stark/features/messaging/widgets/message_reply_preview.dart';
import 'package:stark/utils/snack_bar.dart';

class BottomChatField extends ConsumerStatefulWidget {
  const BottomChatField({super.key});
  @override
  ConsumerState<BottomChatField> createState() => _BottomChatFieldState();
}

class _BottomChatFieldState extends ConsumerState<BottomChatField> {
  final text = TextEditingController();
  final focus = FocusNode();
  bool emoji = false;
  bool busy = false;
  late final String draftKey;
  @override
  void initState() {
    super.initState();
    draftKey =
        ref.read(activeConversationProvider)?.id ??
        'team:${ref.read(userProvider)!.organisation}';
    text.text = ref.read(chatDraftsProvider)[draftKey] ?? '';
    text.addListener(() {
      final drafts = {...ref.read(chatDraftsProvider)};
      if (text.text.isEmpty) {
        drafts.remove(draftKey);
      } else {
        drafts[draftKey] = text.text;
      }
      ref.read(chatDraftsProvider.notifier).state = drafts;
    });
  }

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final draft = text.text.trim();
    if (draft.isEmpty || busy) return;
    setState(() => busy = true);
    final sent = await ref
        .read(messagingControllerProvider.notifier)
        .sendTextMessage(context: context, text: draft);
    if (!mounted) return;
    setState(() {
      if (sent) text.clear();
      busy = false;
    });
  }

  Future<void> attach() async {
    if (!imageUploadsEnabled) return;
    if (busy) return;
    setState(() => busy = true);
    try {
      final selection = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (selection == null) return;
      final image = selection;
      final size = await image.length();
      if (size == null || size > 5 * 1024 * 1024) {
        if (mounted)
          showSnackBar(context, 'Choose an image smaller than 5 MB.');
        return;
      }
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) throw StateError("Image too large");
      await ref
          .read(messagingControllerProvider.notifier)
          .sendImage(context: context, bytes: bytes);
    } catch (_) {
      if (mounted)
        showSnackBar(
          context,
          'The image could not be attached. Please try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ref.watch(messageReplyProvider) != null)
            const MessageReplyPreview(),
          Row(
            children: [
              IconButton(
                tooltip: 'Emoji',
                onPressed: busy
                    ? null
                    : () {
                        setState(() => emoji = !emoji);
                        if (emoji) {
                          focus.unfocus();
                        } else {
                          focus.requestFocus();
                        }
                      },
                icon: const Icon(Icons.emoji_emotions_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: text,
                  focusNode: focus,
                  enabled: !busy,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    hintText: 'Write a message',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onSubmitted: (_) => send(),
                ),
              ),
              if (imageUploadsEnabled)
                IconButton(
                  tooltip: 'Attach image',
                  onPressed: busy ? null : attach,
                  icon: const Icon(Icons.image_outlined),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: FilledButton.icon(
                  onPressed: busy ? null : send,
                  label: Text(busy ? 'Sending…' : 'Send'),
                  icon: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ),
            ],
          ),
          if (emoji)
            SizedBox(
              height: 250,
              child: EmojiPicker(textEditingController: text),
            ),
        ],
      ),
    ),
  );
}
