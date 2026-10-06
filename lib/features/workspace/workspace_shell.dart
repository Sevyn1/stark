import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/controllers/auth_controller.dart';
import '../overview/views/over_view.dart';
import '../overview/views/employee_over_view.dart';
import '../employee/views/employee_view.dart';
import '../messaging/views/messaging_view.dart';
import '../../core/app_navigation.dart';
import 'task_board.dart';
import 'workspace_widgets.dart';
import 'workspace_navigation.dart';

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({super.key});
  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  String selected = 'Overview';
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider)!;
    final labels = user.isAdmin
        ? ['Overview', 'Team', 'Tasks', 'Messages', 'Profile']
        : ['Overview', 'Tasks', 'Messages', 'Profile'];
    const icons = {
      'Overview': Icons.dashboard_outlined,
      'Team': Icons.groups_outlined,
      'Tasks': Icons.task_alt,
      'Messages': Icons.chat_bubble_outline,
      'Profile': Icons.person_outline,
    };
    final pages = <String, Widget>{
      'Overview': user.isAdmin ? const OverView() : const EmployeeOverView(),
      'Team': const EmployeeView(),
      'Tasks': const WorkspaceTaskBoard(),
      'Messages': const MessagingView(),
      'Profile': const WorkspaceProfile(),
    };
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final index = labels.indexOf(selected).clamp(0, labels.length - 1);
    return WorkspaceNavigation(
      select: (value) {
        if (labels.contains(value)) setState(() => selected = value);
      },
      child: Scaffold(
        backgroundColor: const Color(0xfff6f8f5),
        appBar: AppBar(
          backgroundColor: const Color(0xfff6f8f5),
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              const Text(
                'Stark',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xff20613d),
                ),
              ),
              if (user.organisation.isNotEmpty) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    user.organisation,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Color(0xff63756c),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Your profile',
              onPressed: () => setState(() => selected = 'Profile'),
              icon: CircleAvatar(
                radius: 17,
                child: Text(
                  user.firstName.isEmpty
                      ? '?'
                      : user.firstName[0].toUpperCase(),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: SafeArea(
          child: Row(
            children: [
              if (wide)
                NavigationRail(
                  backgroundColor: const Color(0xfff6f8f5),
                  extended: true,
                  minExtendedWidth: 200,
                  selectedIndex: index,
                  onDestinationSelected: (i) =>
                      setState(() => selected = labels[i]),
                  destinations: labels
                      .map(
                        (l) => NavigationRailDestination(
                          icon: Icon(icons[l]),
                          label: Text(l),
                        ),
                      )
                      .toList(),
                ),
              if (wide) const VerticalDivider(width: 1),
              Expanded(child: pages[labels[index]]!),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) =>
                    setState(() => selected = labels[i]),
                destinations: labels
                    .map(
                      (l) =>
                          NavigationDestination(icon: Icon(icons[l]), label: l),
                    )
                    .toList(),
              ),
      ),
    );
  }
}

class WorkspaceProfile extends ConsumerWidget {
  const WorkspaceProfile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(userProvider)!;
    return WorkspacePage(
      title: 'Your account',
      subtitle: 'Keep your details up to date.',
      children: [
        WorkspaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${u.firstName} ${u.lastName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              SelectableText(u.email),
              const SizedBox(height: 12),
              Text(
                '${u.isAdmin ? 'Manager' : 'Employee'} · ${u.organisation.isEmpty ? 'No workspace yet' : u.organisation}',
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        AppNavigator.of(context).push('/edit-profile'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        AppNavigator.of(context).push('/verify-email'),
                    child: const Text('Verify email'),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
