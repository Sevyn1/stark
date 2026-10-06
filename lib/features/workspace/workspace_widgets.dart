import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/controllers/auth_controller.dart';
import '../attendance/attendance_clock.dart';
import '../attendance/repositories/attendance_repository.dart';

final workspaceClockProvider = StreamProvider<DateTime>((ref) async* {
  yield workspaceNow();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => workspaceNow());
});
void watchWorkday(Ref ref) => ref.watch(
  workspaceClockProvider.select(
    (v) => v.valueOrNull == null ? null : attendanceDayKey(v.valueOrNull!),
  ),
);
final todayAttendanceProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  watchWorkday(ref);
  final org = ref.watch(userProvider)?.organisation ?? '';
  return org.isEmpty
      ? Stream.value(null)
      : ref.watch(attendanceRepositoryProvider).watchDay(org);
});
final myAttendanceEntriesProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final user = ref.watch(userProvider);
  return user == null || user.organisation.isEmpty
      ? Stream.value([])
      : ref
            .watch(attendanceRepositoryProvider)
            .watchEmployeeEntries(user.organisation, user.uid);
});
final dailyAttendanceEntriesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
      watchWorkday(ref);
      final user = ref.watch(userProvider);
      return user == null || !user.isAdmin || user.organisation.isEmpty
          ? Stream.value([])
          : ref
                .watch(attendanceRepositoryProvider)
                .watchDayEntries(user.organisation);
    });
DateTime? attendanceTimestamp(dynamic v) => v is Timestamp
    ? v.toDate()
    : v is int
    ? DateTime.fromMillisecondsSinceEpoch(v)
    : null;

class WorkspacePage extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const WorkspacePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xff63756c)),
            ),
            const SizedBox(height: 28),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class WorkspaceCard extends StatelessWidget {
  final Widget child;
  const WorkspaceCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffdfe8e1)),
    ),
    child: child,
  );
}

class WorkspaceEmpty extends StatelessWidget {
  final String title, message;
  final Widget? action;
  const WorkspaceEmpty({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  @override
  Widget build(BuildContext context) => WorkspaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.inbox_outlined, size: 32, color: Color(0xff24734b)),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  final String text;
  final bool positive;
  const StatusPill(this.text, {super.key, this.positive = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: positive ? const Color(0xffe7f5eb) : const Color(0xfffff3db),
      borderRadius: BorderRadius.circular(40),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: positive ? const Color(0xff20613d) : const Color(0xff81590d),
      ),
    ),
  );
}

class MetricRow extends StatelessWidget {
  final List<(String, String)> values;
  const MetricRow(this.values, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: LayoutBuilder(
      builder: (context, size) => Wrap(
        spacing: 16,
        runSpacing: 16,
        children: values
            .map(
              (v) => Container(
                width: size.maxWidth < 500
                    ? (size.maxWidth - 16) / 2
                    : (size.maxWidth - 32) / 3,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xffedf4ef),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.$2,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(v.$1),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}

class WorkspaceLoadError extends StatelessWidget {
  final VoidCallback retry;
  const WorkspaceLoadError({super.key, required this.retry});
  @override
  Widget build(BuildContext context) => WorkspaceEmpty(
    title: 'We couldn’t load this section',
    message: 'Check your connection and try again.',
    action: OutlinedButton(onPressed: retry, child: const Text('Try again')),
  );
}
