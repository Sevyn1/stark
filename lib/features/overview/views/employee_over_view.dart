import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../employee/controllers/employee_controller.dart';
import '../../employee/widgets/employee_invite_tile.dart';
import '../../attendance/repositories/attendance_repository.dart';
import '../../attendance/attendance_clock.dart';
import '../../workspace/workspace_widgets.dart';
import '../../tasks_projects/controllers/task_project_controller.dart';
import '../../workspace/workspace_navigation.dart';

class EmployeeOverView extends ConsumerStatefulWidget {
  const EmployeeOverView({super.key});
  @override
  ConsumerState<EmployeeOverView> createState() => _EmployeeOverviewState();
}

class _EmployeeOverviewState extends ConsumerState<EmployeeOverView> {
  bool busy = false;
  Future<void> attend(bool out) async {
    setState(() => busy = true);
    final repo = ref.read(attendanceRepositoryProvider),
        org = ref.read(userProvider)!.organisation;
    final result = out ? await repo.checkOut(org) : await repo.checkIn(org);
    if (!mounted) return;
    setState(() => busy = false);
    result.fold(
      (e) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message))),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            out
                ? 'You’re checked out. See you next workday.'
                : 'You’re checked in. Have a good day.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider)!;
    final now = ref.watch(workspaceClockProvider).valueOrNull ?? workspaceNow();
    if (user.organisation.isEmpty) {
      final inbox = ref.watch(getInvitesForEmployeeProvider);
      return WorkspacePage(
        title: 'Welcome, ${user.firstName}',
        subtitle: 'Your account is ready. Join a workspace to get started.',
        children: [
          WorkspaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your invitation email',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(user.email),
                const SizedBox(height: 8),
                const Text(
                  'Give this email to your manager so they can invite you.',
                ),
              ],
            ),
          ),
          inbox.when(
            data: (invites) {
              final pending = invites
                  .where((i) => i.status == 'pending')
                  .toList();
              return pending.isEmpty
                  ? const WorkspaceEmpty(
                      title: 'Waiting for your invitation',
                      message:
                          'Your invitations will appear here as soon as your manager sends one.',
                    )
                  : Column(
                      children: pending
                          .map((i) => EmployeeInviteTile(invite: i))
                          .toList(),
                    );
            },
            error: (_, __) => WorkspaceLoadError(
              retry: () => ref.invalidate(getInvitesForEmployeeProvider),
            ),
            loading: () => const LinearProgressIndicator(),
          ),
        ],
      );
    }
    final day = ref.watch(todayAttendanceProvider),
        entries = ref.watch(myAttendanceEntriesProvider),
        tasks = ref.watch(getTasksForEmployeesProvider);
    return WorkspacePage(
      title: 'Good to see you, ${user.firstName}',
      subtitle: '${user.organisation} · ${DateFormat.yMMMMEEEEd().format(now)}',
      children: [
        entries.when(
          data: (list) => MetricRow([
            (
              'Days checked in',
              '${list.where((e) => e['status'] == 'signed').length}',
            ),
            (
              'Completed shifts',
              '${list.where((e) => e['timeOut'] != null).length}',
            ),
            (
              'Open tasks',
              '${tasks.valueOrNull?.where((t) => t.status != 'done').length ?? 0}',
            ),
          ]),
          error: (_, __) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        ),
        day.when(
          data: (data) => entries.when(
            data: (list) {
              final current = list
                  .where((e) => e['dayKey'] == attendanceDayKey(now))
                  .firstOrNull;
              final checked = current?['status'] == 'signed',
                  out = current?['timeOut'] != null;
              final start = attendanceTimestamp(data?['startAt']),
                  timeIn = attendanceTimestamp(current?['timeIn']),
                  timeOut = attendanceTimestamp(current?['timeOut']);
              final opened = data?['windowStart'] != null;
              final late =
                  timeIn != null && start != null && timeIn.isAfter(start);
              return WorkspaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          color: Color(0xff24734b),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Today’s attendance',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        StatusPill(
                          out
                              ? 'Shift complete'
                              : checked
                              ? 'Checked in'
                              : 'Not checked in',
                          positive: checked,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      out
                          ? 'Thanks for today.'
                          : checked
                          ? 'You’re on the record.'
                          : opened
                          ? 'Ready to start your day?'
                          : 'Attendance isn’t open yet.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      opened
                          ? 'Workday starts at ${DateFormat.jm().format(workspaceTime(start!))} · Toronto time'
                          : 'Your manager needs to open today’s attendance before you can check in.',
                    ),
                    if (checked) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Checked in ${timeIn == null ? '' : DateFormat.jm().format(workspaceTime(timeIn))}${late ? ' · Late arrival' : ' · On time'}',
                      ),
                      if (out)
                        Text(
                          'Checked out ${timeOut == null ? '' : DateFormat.jm().format(workspaceTime(timeOut))}',
                        ),
                    ],
                    const SizedBox(height: 24),
                    if (!out)
                      FilledButton.icon(
                        onPressed: busy || !opened
                            ? null
                            : () => attend(checked),
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(checked ? Icons.logout : Icons.login),
                        label: Text(
                          busy
                              ? 'Saving…'
                              : checked
                              ? 'Check out'
                              : 'Check in',
                        ),
                      ),
                  ],
                ),
              );
            },
            error: (_, __) => WorkspaceLoadError(
              retry: () => ref.invalidate(myAttendanceEntriesProvider),
            ),
            loading: () => const LinearProgressIndicator(),
          ),
          error: (_, __) => WorkspaceLoadError(
            retry: () => ref.invalidate(todayAttendanceProvider),
          ),
          loading: () => const LinearProgressIndicator(),
        ),
        WorkspaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your tasks',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        WorkspaceNavigation.of(context)?.select('Tasks'),
                    child: const Text('View all'),
                  ),
                ],
              ),
              tasks.when(
                data: (list) {
                  final open = list
                      .where((t) => t.status != 'done')
                      .take(3)
                      .toList();
                  return open.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'You’re all caught up. New assignments will appear here.',
                          ),
                        )
                      : Column(
                          children: open
                              .map(
                                (t) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.check_box_outline_blank,
                                  ),
                                  title: Text(t.taskName),
                                  subtitle: Text(t.projectName),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => WorkspaceNavigation.of(
                                    context,
                                  )?.select('Tasks'),
                                ),
                              )
                              .toList(),
                        );
                },
                error: (_, __) => WorkspaceLoadError(
                  retry: () => ref.invalidate(getTasksForEmployeesProvider),
                ),
                loading: () => const LinearProgressIndicator(),
              ),
            ],
          ),
        ),
        entries.when(
          data: (list) {
            final history = [...list]
              ..sort(
                (a, b) => (b['dayKey'] ?? '').toString().compareTo(
                  (a['dayKey'] ?? '').toString(),
                ),
              );
            return WorkspaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent attendance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (history.isEmpty)
                    const Text('Your check-ins will be saved here.'),
                  ...history.take(7).map((e) {
                    final time = attendanceTimestamp(e['timeIn']);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e['dayKey'] ?? 'Workday'),
                      subtitle: Text(
                        time == null
                            ? 'No check-in recorded'
                            : 'Checked in at ${DateFormat.jm().format(workspaceTime(time))}',
                      ),
                      trailing: StatusPill(
                        e['timeOut'] != null
                            ? 'Complete'
                            : e['status'] == 'signed'
                            ? 'Checked in'
                            : e['dayKey'] == attendanceDayKey(now)
                            ? 'Pending'
                            : 'No check-in',
                        positive: e['status'] == 'signed',
                      ),
                    );
                  }),
                ],
              ),
            );
          },
          error: (_, __) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
