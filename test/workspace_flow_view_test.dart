import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark/features/auth/controllers/auth_controller.dart';
import 'package:stark/features/employee/controllers/employee_controller.dart';
import 'package:stark/features/tasks_projects/controllers/task_project_controller.dart';
import 'package:stark/features/workspace/workspace_shell.dart';
import 'package:stark/features/workspace/workspace_widgets.dart';
import 'package:stark/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

UserModel profile(bool manager) => UserModel(
  uid: manager ? 'm' : 'e',
  firstName: 'Jamie',
  lastName: 'Lee',
  profilePic: '',
  email: 'jamie@example.test',
  isAdmin: manager,
  organisation: 'Workspace',
  role: 'Developer',
  phone: '',
);
void main() {
  testWidgets('Mobile employee sees self check-in and usable task navigation', (
    tester,
  ) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProvider.overrideWith((ref) => profile(false)),
          workspaceClockProvider.overrideWith(
            (ref) => Stream.value(DateTime.utc(2026, 10, 5, 14)),
          ),
          todayAttendanceProvider.overrideWith(
            (ref) => Stream.value({
              'windowStart': Timestamp.fromDate(DateTime.utc(2026, 10, 5, 4)),
              'startAt': Timestamp.fromDate(DateTime.utc(2026, 10, 5, 13)),
            }),
          ),
          myAttendanceEntriesProvider.overrideWith((ref) => Stream.value([])),
          getTasksForEmployeesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: WorkspaceShell()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Check in'), findsOneWidget);
    expect(find.text('Not checked in'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    expect(find.text('No assignments yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Desktop manager reviews attendance rather than signing for employees',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProvider.overrideWith((ref) => profile(true)),
            workspaceClockProvider.overrideWith(
              (ref) => Stream.value(DateTime.utc(2026, 10, 5, 14)),
            ),
            todayAttendanceProvider.overrideWith((ref) => Stream.value(null)),
            dailyAttendanceEntriesProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            getEmployeesProvider.overrideWith(
              (ref) => Stream.value([profile(false)]),
            ),
          ],
          child: const MaterialApp(home: WorkspaceShell()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open today’s attendance'), findsOneWidget);
      expect(find.text('Waiting for employee check-in'), findsOneWidget);
      expect(find.text('Sign'), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
