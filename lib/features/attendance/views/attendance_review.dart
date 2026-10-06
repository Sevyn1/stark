import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../employee/controllers/employee_controller.dart';
import '../../workspace/workspace_widgets.dart';
import '../../workspace/workspace_navigation.dart';
import '../attendance_clock.dart';
import '../repositories/attendance_repository.dart';
import '../../../models/attemdance_model.dart';
import '../../../core/app_navigation.dart';

class AttendanceReview extends ConsumerStatefulWidget {
  const AttendanceReview({super.key});
  @override
  ConsumerState<AttendanceReview> createState() => _AttendanceReviewState();
}

class _AttendanceReviewState extends ConsumerState<AttendanceReview> {
  bool busy = false;
  Future<void> openDay() async {
    final shift = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Workday start · Toronto time',
    );
    if (shift == null || !mounted) return;
    setState(() => busy = true);
    final org = ref.read(userProvider)!.organisation;
    final result = await ref
        .read(attendanceRepositoryProvider)
        .createAttendance(
          AttendanceModel(
            employeeId: '',
            timeIn: null,
            status: 'notsigned',
            organisationName: org,
          ),
          org,
          shiftStartMinutes: shift.hour * 60 + shift.minute,
        );
    if (!mounted) return;
    setState(() => busy = false);
    result.fold(
      (e) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message))),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Attendance is open. Employees can check themselves in.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider)!;
    final now = ref.watch(workspaceClockProvider).valueOrNull ?? workspaceNow();
    if (user.organisation.isEmpty)
      return WorkspacePage(
        title: 'Start your workspace',
        subtitle: 'Bring your team, projects and workday into one place.',
        children: [
          WorkspaceEmpty(
            title: 'Set up your team',
            message:
                'Create a workspace first, then invite employees using their account email.',
            action: FilledButton.icon(
              onPressed: () =>
                  AppNavigator.of(context).push('/create-organisation'),
              icon: const Icon(Icons.add),
              label: const Text('Create workspace'),
            ),
          ),
        ],
      );
    final day = ref.watch(todayAttendanceProvider),
        entries = ref.watch(dailyAttendanceEntriesProvider),
        people = ref.watch(getEmployeesProvider);
    return WorkspacePage(
      title: 'Your team, today',
      subtitle:
          'Your workspace · ${DateFormat.yMMMMEEEEd().format(now)} · Toronto time',
      children: [
        day.when(
          data: (record) {
            final opened = record?['windowStart'] != null,
                start = attendanceTimestamp(record?['startAt']);
            final memberIds = (people.valueOrNull ?? [])
                .map((p) => p.uid)
                .toSet();
            final list = (entries.valueOrNull ?? [])
                .where((e) => memberIds.contains(e['employeeId']))
                .toList();
            final checked = list.where((e) => e['status'] == 'signed').length;
            final late = list.where((e) {
              final t = attendanceTimestamp(e['timeIn']);
              return t != null && start != null && t.isAfter(start);
            }).length;
            final total = people.valueOrNull?.length ?? 0;
            return Column(
              children: [
                MetricRow([
                  ('Checked in', '$checked / $total'),
                  ('Pending', '${(total - checked).clamp(0, total)}'),
                  ('Late arrivals', '$late'),
                ]),
                WorkspaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Today’s attendance',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          StatusPill(
                            opened ? 'Open' : 'Not opened',
                            positive: opened,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        opened
                            ? 'Employees check themselves in and out. Arrival times are recorded by Firebase.'
                            : 'Choose the workday start time. Your employees will then be able to check in.',
                      ),
                      const SizedBox(height: 12),
                      if (opened)
                        Text(
                          'Start ${DateFormat.jm().format(workspaceTime(start!))} · America/Toronto',
                        ),
                      if (!opened) ...[
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: busy ? null : openDay,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            busy ? 'Opening…' : 'Open today’s attendance',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
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
                      'Team attendance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        WorkspaceNavigation.of(context)?.select('Team'),
                    child: const Text('Manage team'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              people.when(
                data: (members) => entries.when(
                  data: (list) {
                    if (members.isEmpty)
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Invite your first employee from Team to get started.',
                        ),
                      );
                    return Column(
                      children: members.map((person) {
                        final entry = list
                            .where((e) => e['employeeId'] == person.uid)
                            .firstOrNull;
                        final signed = entry?['status'] == 'signed',
                            inTime = attendanceTimestamp(entry?['timeIn']),
                            outTime = attendanceTimestamp(entry?['timeOut']);
                        final start = attendanceTimestamp(
                          day.valueOrNull?['startAt'],
                        );
                        final late =
                            inTime != null &&
                            start != null &&
                            inTime.isAfter(start);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                child: Text(
                                  person.firstName.isEmpty
                                      ? '?'
                                      : person.firstName[0].toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${person.firstName} ${person.lastName}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      inTime == null
                                          ? 'Waiting for employee check-in'
                                          : 'In ${DateFormat.jm().format(workspaceTime(inTime))}${outTime == null ? '' : ' · Out ${DateFormat.jm().format(workspaceTime(outTime))}'}',
                                      style: const TextStyle(
                                        color: Color(0xff63756c),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusPill(
                                outTime != null
                                    ? 'Complete'
                                    : signed
                                    ? late
                                          ? 'Late'
                                          : 'On time'
                                    : 'Pending',
                                positive: signed && !late,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                  error: (_, __) => WorkspaceLoadError(
                    retry: () => ref.invalidate(dailyAttendanceEntriesProvider),
                  ),
                  loading: () => const LinearProgressIndicator(),
                ),
                error: (_, __) => WorkspaceLoadError(
                  retry: () => ref.invalidate(getEmployeesProvider),
                ),
                loading: () => const LinearProgressIndicator(),
              ),
            ],
          ),
        ),
        WorkspaceCard(
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    WorkspaceNavigation.of(context)?.select('Team'),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Invite employees'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    AppNavigator.of(context).push('/create-project'),
                icon: const Icon(Icons.add_task),
                label: const Text('Create a project'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
