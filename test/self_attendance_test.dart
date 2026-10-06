import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark/features/attendance/repositories/attendance_repository.dart';
import 'package:stark/features/attendance/attendance_clock.dart';
import 'package:stark/models/attemdance_model.dart';

void main() {
  test(
    'Employee self check-in and checkout preserve the first recorded times',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('organisations').doc('A').set({
        'employees': ['e'],
        'managers': ['m'],
      });
      final now = DateTime.utc(2026, 10, 5, 14);
      final manager = AttendanceRepository(
        firestore: db,
        actorUid: 'm',
        now: () => now,
      );
      expect(
        (await manager.createAttendance(
          const AttendanceModel(
            employeeId: '',
            timeIn: null,
            status: 'notsigned',
            organisationName: 'A',
          ),
          'A',
        )).isRight(),
        true,
      );
      final employee = AttendanceRepository(
        firestore: db,
        actorUid: 'e',
        now: () => now,
      );
      expect((await employee.checkIn('A')).isRight(), true);
      final ref = db.collection('attendance').doc(employee.entryId('A', 'e'));
      final first = (await ref.get()).data()!['timeIn'];
      expect(first, isNotNull);
      expect((await employee.checkIn('A')).isRight(), true);
      expect((await ref.get()).data()!['timeIn'], first);
      expect((await employee.checkOut('A')).isRight(), true);
      final out = (await ref.get()).data()!['timeOut'];
      expect(out, isNotNull);
      expect((await employee.checkOut('A')).isRight(), true);
      expect((await ref.get()).data()!['timeOut'], out);
    },
  );
  test(
    'Employee cannot open the workday or check in to another workspace',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('organisations').doc('A').set({
        'employees': ['e'],
        'managers': ['m'],
      });
      await db.collection('organisations').doc('B').set({
        'employees': ['other'],
        'managers': ['m'],
      });
      final employee = AttendanceRepository(firestore: db, actorUid: 'e');
      expect(
        (await employee.createAttendance(
          const AttendanceModel(
            employeeId: '',
            timeIn: null,
            status: 'notsigned',
            organisationName: 'A',
          ),
          'A',
        )).isLeft(),
        true,
      );
      expect((await employee.checkIn('B')).isLeft(), true);
      expect((await employee.checkOut('A')).isLeft(), true);
      expect((await db.collection('attendance').get()).docs, isEmpty);
    },
  );
  test(
    'Toronto workdays roll over independently of device timezone and DST',
    () {
      expect(attendanceDayKey(DateTime.utc(2026, 10, 6, 2)), '2026-10-05');
      expect(attendanceDayKey(DateTime.utc(2026, 10, 6, 4)), '2026-10-06');
      final spring = DateTime.utc(2026, 3, 8, 12);
      expect(workdayEnd(spring).difference(workdayTime(spring, 0)).inHours, 23);
      final autumn = DateTime.utc(2026, 11, 1, 12);
      expect(workdayEnd(autumn).difference(workdayTime(autumn, 0)).inHours, 25);
    },
  );
}
