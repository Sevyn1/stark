import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/features/employee/widgets/employee_invite_tile.dart';
import 'package:stark/models/invite_model.dart';

void main() {
  testWidgets(
    'Pending invitation renders and accepts without private profile access',
    (tester) async {
      var accepted = false;
      var rejected = false;
      // No manager profile, workspace record or Firebase Auth instance is available.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EmployeeInviteTile(
                invite: InviteModel(
                  organisationName: 'Workspace',
                  receiverId: 'employee',
                  managerId: 'private-manager',
                  sentAt: DateTime(2026, 10, 5),
                  actionAt: DateTime(2026, 10, 5),
                  status: 'pending',
                ),
                approve: () => accepted = true,
                reject: () => rejected = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Workspace'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Accept'));
      expect(accepted, isTrue);
      await tester.tap(find.text('Reject'));
      expect(rejected, isTrue);
    },
  );
}
