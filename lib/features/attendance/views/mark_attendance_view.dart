import 'package:flutter/material.dart';
import 'attendance_review.dart';

class MarkAttendanceView extends StatelessWidget {
  const MarkAttendanceView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Team attendance')),
    body: const AttendanceReview(),
  );
}
