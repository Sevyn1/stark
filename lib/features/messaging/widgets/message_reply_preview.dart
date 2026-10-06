import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/message_reply_provider.dart';
import '../../../core/enums/enums.dart';

class MessageReplyPreview extends ConsumerWidget {
  const MessageReplyPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reply = ref.watch(messageReplyProvider);
    if (reply == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xffedf4ef),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reply.isMe
                      ? 'Replying to yourself'
                      : reply.senderName.isEmpty
                      ? 'Replying to a teammate'
                      : 'Replying to ${reply.senderName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Cancel reply',
                onPressed: () =>
                    ref.read(messageReplyProvider.notifier).state = null,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          Text(
            reply.messageEnum == MessageEnum.text ? reply.message : 'Photo',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
