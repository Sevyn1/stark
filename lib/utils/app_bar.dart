import 'package:flutter/material.dart';
import '../features/workspace/workspace_navigation.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  const MyAppBar({super.key, this.title});
  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    backgroundColor: const Color(0xfff6f8f5),
    surfaceTintColor: Colors.transparent,
    title: Text(
      title ?? '',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    ),
    actions: [
      if (WorkspaceNavigation.of(context) == null)
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
    ],
  );
  @override
  Size get preferredSize => const Size.fromHeight(58);
}
