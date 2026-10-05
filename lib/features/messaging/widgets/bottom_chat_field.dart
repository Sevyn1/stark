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
        .sendTextMessageManager(context: context, text: draft);
    if (!mounted) return;
    setState(() {
      if (sent) text.clear();
      busy = false;
    });
  }

  Future<void> attach() async {
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
    child: Column(
      children: [
        if (ref.watch(messageReplyProvider) != null)
          const MessageReplyPreview(),
        Row(
          children: [
            IconButton(
              tooltip: 'Emoji',
              onPressed: busy ? null : () => setState(() => emoji = !emoji),
              icon: const Icon(Icons.emoji_emotions_outlined),
            ),
            Expanded(
              child: TextField(
                controller: text,
                focusNode: focus,
                enabled: !busy,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Write a message'),
                onSubmitted: (_) => send(),
              ),
            ),
            IconButton(
              tooltip: 'Attach image',
              onPressed: busy ? null : attach,
              icon: const Icon(Icons.image_outlined),
            ),
            IconButton(
              tooltip: 'Send message',
              onPressed: busy ? null : send,
              icon: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
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
  );
}
