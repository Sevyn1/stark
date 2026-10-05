import 'package:flutter/material.dart';
import 'package:stark/core/app_navigation.dart';
import '../../onboarding/widgets/account_header.dart';

/// Integrates both role choices from the earlier Employee Management onboarding.
class SelectUserTypeView extends StatelessWidget {
  const SelectUserTypeView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose your role')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            children: [
              const AccountHeader(subtitle: 'How will you use Stark?'),
              const SizedBox(height: 30),
              for (final entry in const [
                [
                  'Manager',
                  'admin',
                  'manager.png',
                  'Create a workspace, invite employees and manage projects.',
                ],
                [
                  'Employee',
                  'employee',
                  'people-talking.png',
                  'Accept your invitation, work on tasks and join team conversations.',
                ],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(18),
                      leading: Image.asset(
                        'lib/assets/employee_management/${entry[2]}',
                        width: 52,
                        height: 60,
                      ),
                      title: Text(
                        entry[0],
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(entry[3]),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          AppNavigator.of(context).push('/sign-up/${entry[1]}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
