import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stark/features/employee/controllers/employee_controller.dart';
import 'package:stark/models/invite_model.dart';

/// An invitation must be readable before the recipient joins the workspace.
/// Render its own metadata without fetching private manager/workspace records.
class EmployeeInviteTile extends ConsumerWidget {
  final InviteModel invite;
  final void Function()? approve;
  final void Function()? reject;

  const EmployeeInviteTile({
    super.key,
    required this.invite,
    this.approve,
    this.reject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(employeeControllerProvider);
    return Card(
      margin: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              invite.organisationName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Your workspace manager invited you on ${DateFormat.yMMMMd().format(invite.sentAt)}.',
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed:
                        reject ??
                        () => ref
                            .read(employeeControllerProvider.notifier)
                            .rejectInvite(invite, context),
                    child: const Text('Reject'),
                  ),
                  FilledButton(
                    onPressed:
                        approve ??
                        () => ref
                            .read(employeeControllerProvider.notifier)
                            .acceptInvite(invite, context),
                    child: const Text('Accept'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
