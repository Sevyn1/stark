import 'package:flutter/material.dart';

/// Consolidated from Employee Management's Header/Logo widgets.
class AccountHeader extends StatelessWidget {
  final String subtitle;
  const AccountHeader({super.key, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(children: [
        const Text('Stark',
            style: TextStyle(
                color: Color.fromRGBO(83, 182, 110, 1),
                fontSize: 46,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(subtitle,
            style: const TextStyle(color: Color(0xff7d7d7d), fontSize: 16)),
      ]);
}
