import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/controllers/auth_controller.dart';
import '../tasks_projects/controllers/task_project_controller.dart';
import '../tasks_projects/repositories/task_project_repository.dart';
import '../../core/app_navigation.dart';
import 'workspace_widgets.dart';

class WorkspaceTaskBoard extends ConsumerStatefulWidget {
  const WorkspaceTaskBoard({super.key});
  @override
  ConsumerState<WorkspaceTaskBoard> createState() => _TaskBoardState();
}

class _TaskBoardState extends ConsumerState<WorkspaceTaskBoard> {
  final Set<String> busy = {};
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider)!;
    if (user.organisation.isEmpty)
      return const WorkspacePage(
        title: 'Tasks',
        subtitle: 'One place for your work.',
        children: [
          WorkspaceEmpty(
            title: 'Join a workspace first',
            message: 'Your tasks will appear after you accept an invitation.',
          ),
        ],
      );
    if (user.isAdmin) {
      final projects = ref.watch(getProjectsForOrganisationsProvider);
      return WorkspacePage(
        title: 'Projects',
        subtitle: 'Plan the work. Assign tasks. Follow progress.',
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => AppNavigator.of(context).push('/create-project'),
              icon: const Icon(Icons.add),
              label: const Text('New project'),
            ),
          ),
          const SizedBox(height: 20),
          projects.when(
            data: (list) => list.isEmpty
                ? const WorkspaceEmpty(
                    title: 'Your first project starts here',
                    message: 'Create a project, then add tasks for your team.',
                  )
                : Column(
                    children: list
                        .map(
                          (p) => WorkspaceCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                p.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              subtitle: Text(
                                '${p.taskIds.length} tasks · ${p.employeeIds.length} assigned employees',
                              ),
                              trailing: StatusPill(
                                p.status == 'done'
                                    ? 'Completed'
                                    : 'In progress',
                                positive: p.status == 'done',
                              ),
                              onTap: () => AppNavigator.of(
                                context,
                              ).push('/project/${Uri.encodeComponent(p.name)}'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
            error: (_, __) => WorkspaceLoadError(
              retry: () => ref.invalidate(getProjectsForOrganisationsProvider),
            ),
            loading: () => const LinearProgressIndicator(),
          ),
        ],
      );
    }
    final tasks = ref.watch(getTasksForEmployeesProvider);
    return WorkspacePage(
      title: 'Your tasks',
      subtitle: 'Update your progress as you finish your work.',
      children: [
        tasks.when(
          data: (list) => list.isEmpty
              ? const WorkspaceEmpty(
                  title: 'No assignments yet',
                  message: 'Your manager’s task assignments will appear here.',
                )
              : Column(
                  children: list
                      .map(
                        (t) => WorkspaceCard(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: t.status == 'done',
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              t.taskName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('${t.projectName}\n${t.description}'),
                            ),
                            onChanged: busy.contains(t.taskName)
                                ? null
                                : (done) async {
                                    setState(() => busy.add(t.taskName));
                                    final repo = ref.read(
                                      tasksProjectRepositoryProvider,
                                    );
                                    final result = done == true
                                        ? await repo.updateTaskStatusDone(
                                            t.taskName,
                                          )
                                        : await repo.updateTaskStatusProgress(
                                            t.taskName,
                                          );
                                    if (!mounted) return;
                                    setState(() => busy.remove(t.taskName));
                                    result.fold(
                                      (e) => ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(content: Text(e.message)),
                                          ),
                                      (_) {},
                                    );
                                  },
                          ),
                        ),
                      )
                      .toList(),
                ),
          error: (_, __) => WorkspaceLoadError(
            retry: () => ref.invalidate(getTasksForEmployeesProvider),
          ),
          loading: () => const LinearProgressIndicator(),
        ),
      ],
    );
  }
}
