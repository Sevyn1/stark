import 'package:flutter/widgets.dart';

class WorkspaceNavigation extends InheritedWidget {
  final void Function(String) select;
  const WorkspaceNavigation({
    super.key,
    required this.select,
    required super.child,
  });
  static WorkspaceNavigation? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceNavigation>();
  @override
  bool updateShouldNotify(WorkspaceNavigation old) => select != old.select;
}
