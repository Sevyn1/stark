import 'package:flutter/material.dart';
import 'package:stark/core/app_navigation.dart';
import '../widgets/image_and_description.dart';
import '../widgets/account_header.dart';

/// Working onboarding using the earlier Employee Management artwork and widget.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: Center(
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(children: [
                const AccountHeader(subtitle: 'Your team, organised.'),
                const SizedBox(height: 28),
                const ImageAndDescription(
                    image: 'lib/assets/employee_management/Calendar.png',
                    textSpace: 24,
                    text:
                        'Manage employees, projects, tasks and attendance in one workspace.'),
                const SizedBox(height: 32),
                ElevatedButton(
                    onPressed: () =>
                        AppNavigator.of(context).push('/select-role'),
                    child: const Text('Create an account')),
                TextButton(
                    onPressed: () => AppNavigator.of(context).push('/login'),
                    child: const Text('Sign in')),
              ]),
            )),
      )));
}
