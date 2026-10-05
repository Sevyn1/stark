import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stark/features/attendance/views/mark_attendance_view.dart';
import 'package:stark/features/auth/views/login_view.dart';
import 'package:stark/features/auth/views/sign_up_view.dart';
import 'package:stark/features/auth/views/user_type_view.dart';
import 'package:stark/features/auth/views/recovery_view.dart';
import 'package:stark/features/auth/views/verification_view.dart';
import 'package:stark/features/onboarding/views/welcome_view.dart';
import 'package:stark/features/base_drawer_wrapper/views/base_drawer_wrapper.dart';
import 'package:stark/features/base_drawer_wrapper/views/employee_base_drawer_wrapper.dart';
import 'package:stark/features/organisation/views/create_organisation_view.dart';
import 'package:stark/features/profile/views/edit_profile_view.dart';
import 'package:stark/features/tasks_projects/views/create_project_view.dart';
import 'package:stark/features/tasks_projects/views/project_view.dart';
import 'package:stark/models/user_model.dart';

GoRouter buildAppRouter(UserModel? profile) => GoRouter(
  initialLocation: '/',
  overridePlatformDefaultLocation: true,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => profile == null
          ? const WelcomeView()
          : profile.isAdmin
          ? const BaseDrawerWrapper()
          : const EmployeeBaseDrawerWrapper(),
    ),
    if (profile == null) ...[
      GoRoute(
        path: '/select-role',
        builder: (_, __) => const SelectUserTypeView(),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginView()),
      GoRoute(path: '/recovery', builder: (_, __) => const RecoveryView()),
      GoRoute(
        path: '/sign-up/:type',
        builder: (_, state) => SignUpView(type: state.pathParameters['type']!),
      ),
    ] else ...[
      GoRoute(
        path: '/verify-email',
        builder: (_, __) => const VerificationView(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (_, __) => const EditProfileView(),
      ),
      GoRoute(
        path: '/project/:name',
        builder: (_, state) => ProjectView(name: state.pathParameters['name']!),
      ),
      if (profile.isAdmin) ...[
        GoRoute(
          path: '/create-organisation',
          builder: (_, __) => const CreateOrganisationView(),
        ),
        GoRoute(
          path: '/mark-attendance',
          builder: (_, __) => const MarkAttendanceView(),
        ),
        GoRoute(
          path: '/create-project',
          builder: (_, __) => const CreateProjectView(),
        ),
      ],
    ],
  ],
  errorBuilder: (context, _) => Scaffold(
    appBar: AppBar(title: const Text('Page unavailable')),
    body: Center(
      child: TextButton(
        onPressed: () => GoRouter.of(context).go('/'),
        child: const Text('Return to your workspace'),
      ),
    ),
  ),
);
