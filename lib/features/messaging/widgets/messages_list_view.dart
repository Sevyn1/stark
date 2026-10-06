import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/messaging_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../attendance/attendance_clock.dart';
import '../../../core/providers/message_reply_provider.dart';
import '../../../core/enums/enums.dart';
import '../../workspace/workspace_widgets.dart';

class MessagesListView extends ConsumerWidget {
  const MessagesListView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider)!;
    return ref
        .watch(getGroupChatStreamProvider)
        .when(
          data: (messages) {
            if (messages.isEmpty)
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 40,
                        color: Color(0xff24734b),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Start the conversation',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Write a message below to get started.'),
                    ],
                  ),
                ),
              );
            final latest = messages.reversed.toList();
            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: latest.length,
              itemBuilder: (context, index) {
                final m = latest[index], mine = m.senderId == user.uid;
                return Align(
                  alignment: mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: mine ? const Color(0xffe2f1e7) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xffdfe8e1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mine
                                ? 'You'
                                : m.senderUsername.isEmpty
                                ? 'Teammate'
                                : m.senderUsername,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff24734b),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (m.repliedMessage.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: Color(0xff24734b),
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                m.repliedMessage,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          m.type == MessageEnum.image
                              ? Image.network(
                                  m.text,
                                  height: 180,
                                  errorBuilder: (_, __, ___) =>
                                      const Text('Image unavailable'),
                                )
                              : SelectableText(
                                  m.text,
                                  style: const TextStyle(fontSize: 16),
                                ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat.jm().format(
                                  workspaceTime(m.timeSent),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff63756c),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Reply to message',
                                onPressed: () =>
                                    ref
                                        .read(messageReplyProvider.notifier)
                                        .state = MessageReply(
                                      m.text,
                                      mine,
                                      m.type,
                                    ),
                                icon: const Icon(Icons.reply, size: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          error: (_, __) => WorkspaceLoadError(
            retry: () => ref.invalidate(getGroupChatStreamProvider),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        );
  }
}
