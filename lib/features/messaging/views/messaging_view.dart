import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/conversation_repository.dart';
import '../controllers/messaging_controller.dart';
import '../widgets/bottom_chat_field.dart';
import '../widgets/messages_list_view.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../workspace/workspace_widgets.dart';
import '../../../core/providers/message_reply_provider.dart';
import '../../../models/user_model.dart';

class MessagingView extends ConsumerStatefulWidget {
  const MessagingView({super.key});
  @override
  ConsumerState<MessagingView> createState() => _MessagingViewState();
}

class _MessagingViewState extends ConsumerState<MessagingView> {
  String query = '';
  bool choosing = true;
  String? opening;
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> selectPerson(UserModel person) async {
    if (opening != null) return;
    setState(() => opening = person.uid);
    try {
      final room = await ref
          .read(conversationRepositoryProvider)
          .open(person, ref.read(userProvider)!.organisation);
      if (!mounted) return;
      ref.read(messageReplyProvider.notifier).state = null;
      ref.read(activeConversationProvider.notifier).state = room;
      setState(() => choosing = false);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => opening = null);
    }
  }

  void selectTeam() {
    ref.read(activeConversationProvider.notifier).state = null;
    ref.read(messageReplyProvider.notifier).state = null;
    setState(() => choosing = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider)!;
    if (user.organisation.isEmpty)
      return const WorkspacePage(
        title: 'Messages',
        subtitle: 'Stay connected with your team.',
        children: [
          WorkspaceEmpty(
            title: 'Join your team first',
            message:
                'Accept a workspace invitation to find people and send messages.',
          ),
        ],
      );
    final people = ref.watch(workspacePeopleProvider);
    final room = ref.watch(activeConversationProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final contacts = Material(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Find someone in your workspace.'),
                const SizedBox(height: 20),
                TextField(
                  controller: search,
                  onChanged: (v) =>
                      setState(() => query = v.toLowerCase().trim()),
                  decoration: const InputDecoration(
                    labelText: 'Search teammates',
                    hintText: 'Name or email',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
            title: const Text('Team chat'),
            subtitle: Text(user.organisation),
            onTap: opening == null ? selectTeam : null,
          ),
          const Divider(),
          Expanded(
            child: people.when(
              data: (all) {
                final list =
                    all
                        .where(
                          (p) =>
                              p.uid != user.uid &&
                              '${p.firstName} ${p.lastName} ${p.email}'
                                  .toLowerCase()
                                  .contains(query),
                        )
                        .toList()
                      ..sort((a, b) => a.firstName.compareTo(b.firstName));
                if (list.isEmpty)
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        query.isEmpty
                            ? 'No other teammates yet. A manager can invite employees from Team.'
                            : 'No teammate matches that name or email.',
                      ),
                    ),
                  );
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final p = list[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          p.firstName.isEmpty
                              ? '?'
                              : p.firstName[0].toUpperCase(),
                        ),
                      ),
                      title: Text('${p.firstName} ${p.lastName}'),
                      subtitle: Text(
                        p.isAdmin
                            ? 'Manager'
                            : p.role.isEmpty
                            ? 'Employee'
                            : p.role,
                      ),
                      trailing: opening == p.uid
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: opening == null ? () => selectPerson(p) : null,
                    );
                  },
                );
              },
              error: (_, __) => WorkspaceLoadError(
                retry: () => ref.invalidate(workspacePeopleProvider),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
    final conversation = Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xffdfe8e1))),
          ),
          child: Row(
            children: [
              if (!wide)
                IconButton(
                  tooltip: 'Back to people',
                  onPressed: () => setState(() => choosing = true),
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room?.name ?? 'Team chat',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room == null
                          ? 'Everyone in ${user.organisation}'
                          : 'Private conversation',
                      style: const TextStyle(
                        color: Color(0xff63756c),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: MessagesListView()),
        BottomChatField(key: ValueKey(room?.id ?? 'team:${user.organisation}')),
      ],
    );
    if (wide)
      return Row(
        children: [
          SizedBox(width: 280, child: contacts),
          const VerticalDivider(width: 1),
          Expanded(
            child: choosing
                ? const Center(
                    child: Text('Choose a teammate or open your team chat.'),
                  )
                : conversation,
          ),
        ],
      );
    return choosing ? contacts : conversation;
  }
}
