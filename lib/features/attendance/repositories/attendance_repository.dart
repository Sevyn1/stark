import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:stark/core/failure.dart';
import 'package:stark/features/auth/controllers/auth_controller.dart';
import '../attendance_clock.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/core/type_defs.dart';
import 'package:stark/models/attemdance_model.dart';
import 'package:stark/models/attendance_record_model.dart';

final attendanceRepositoryProvider = Provider(
  (ref) => AttendanceRepository(
    firestore: ref.watch(firestoreProvider),
    actorUid: ref.watch(userProvider)?.uid,
  ),
);

/// Toronto workdays and employee-owned attendance entries. New dashboards derive
/// attendance from entries; legacy aggregate fields remain for compatibility.
class AttendanceRepository {
  final FirebaseFirestore _firestore;
  final DateTime Function() _now;
  final String? actorUid;
  AttendanceRepository({
    required FirebaseFirestore firestore,
    DateTime Function()? now,
    this.actorUid,
  }) : _firestore = firestore,
       _now = now ?? DateTime.now;
  String get dayKey => attendanceDayKey(_now());

  String recordId(String org) => '${Uri.encodeComponent(org)}::$dayKey';
  String entryId(String org, String employee) => '${recordId(org)}::$employee';
  CollectionReference<Map<String, dynamic>> get records =>
      _firestore.collection('attendanceRecords');
  CollectionReference<Map<String, dynamic>> get entries =>
      _firestore.collection('attendance');

  FutureVoid createAttendance(
    AttendanceModel attendance,
    String orgName, {
    int shiftStartMinutes = 540,
  }) async {
    try {
      if (orgName.isEmpty) throw StateError('Choose an organisation first.');
      await _firestore.runTransaction((transaction) async {
        final org = await transaction.get(
          _firestore.collection('organisations').doc(orgName),
        );
        final record = await transaction.get(records.doc(recordId(orgName)));
        if (!org.exists) throw StateError('Organisation not found');
        if (actorUid != null &&
            !List<String>.from(
              org.data()!['managers'] ?? [],
            ).contains(actorUid))
          throw StateError('Only a manager can open attendance.');
        final timing = {
          'windowStart': Timestamp.fromDate(workdayTime(_now(), 0)),
          'windowEnd': Timestamp.fromDate(workdayEnd(_now())),
          'startAt': Timestamp.fromDate(workdayTime(_now(), shiftStartMinutes)),
          'timezone': attendanceTimezone,
        };
        if (record.exists) {
          // Upgrade an older workday without clearing sign-ins or changing an existing shift.
          if (record.data()!['windowStart'] == null)
            transaction.update(record.reference, timing);
          return;
        }
        final members = List<String>.from(org.data()!['employees'] ?? []);
        if (members.length > 450)
          throw StateError(
            'This attendance workflow supports up to 450 employees.',
          );
        for (final employee in members) {
          transaction.set(entries.doc(entryId(orgName, employee)), {
            ...attendance
                .copyWith(
                  employeeId: employee,
                  organisationName: orgName,
                  status: 'notsigned',
                )
                .toMap(),
            'dayKey': dayKey,
            'recordId': recordId(orgName),
            'timeOut': null,
          });
        }
        transaction.set(records.doc(recordId(orgName)), {
          ...AttendanceRecordModel(
            day: _now(),
            organisationName: orgName,
            early: [],
            late: [],
            present: [],
            absent: members,
          ).toMap(),
          'dayKey': dayKey,
          ...timing,
        });
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid signAttendance(
    String employeeId,
    String orgName, {
    bool absent = false,
  }) async {
    try {
      final now = _now();
      await _firestore.runTransaction((transaction) async {
        final entryRef = entries.doc(entryId(orgName, employeeId));
        final recordRef = records.doc(recordId(orgName));
        final entry = await transaction.get(entryRef);
        final record = await transaction.get(recordRef);
        if (!entry.exists || !record.exists)
          throw StateError('Open today’s attendance before signing.');
        final data = record.data()!;
        final present = List<String>.from(data['present'] ?? [])
          ..remove(employeeId);
        final missing = List<String>.from(data['absent'] ?? [])
          ..remove(employeeId);
        final early = List<String>.from(data['early'] ?? [])
          ..remove(employeeId);
        final late = List<String>.from(data['late'] ?? [])..remove(employeeId);
        if (absent) {
          missing.add(employeeId);
        } else {
          present.add(employeeId);
          final time = entry.data()!['timeIn'];
          final signedAt = time == null
              ? now
              : DateTime.fromMillisecondsSinceEpoch(time);
          (signedAt.isBefore(DateTime(now.year, now.month, now.day, 9))
                  ? early
                  : late)
              .add(employeeId);
        }
        transaction.update(entryRef, {
          'status': absent ? 'neversigned' : 'signed',
          'timeIn': absent
              ? null
              : entry.data()!['timeIn'] ?? now.millisecondsSinceEpoch,
        });
        transaction.update(recordRef, {
          'present': present,
          'absent': missing,
          'early': early,
          'late': late,
        });
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid checkIn(String orgName) async {
    try {
      final uid = actorUid;
      if (uid == null || orgName.isEmpty)
        throw StateError('Sign in to your workspace first.');
      await _firestore.runTransaction((transaction) async {
        final org = await transaction.get(
          _firestore.collection('organisations').doc(orgName),
        );
        if (!org.exists ||
            !List<String>.from(org.data()!['employees'] ?? []).contains(uid))
          throw StateError(
            'Join this workspace as an employee before checking in.',
          );
        final day = await transaction.get(records.doc(recordId(orgName)));
        final entryRef = entries.doc(entryId(orgName, uid));
        final entry = await transaction.get(entryRef);
        if (!day.exists || day.data()!['windowStart'] == null)
          throw StateError('Your manager needs to open attendance for today.');
        final end = (day.data()!['windowEnd'] as Timestamp).toDate();
        if (!_now().isBefore(end))
          throw StateError('This attendance day has closed.');
        if (entry.data()?['status'] == 'signed') return;
        final values = {
          'employeeId': uid,
          'organisationName': orgName,
          'dayKey': dayKey,
          'recordId': recordId(orgName),
          'status': 'signed',
          'timeIn': FieldValue.serverTimestamp(),
          'timeOut': null,
        };
        if (entry.exists) {
          transaction.update(entryRef, {
            'status': 'signed',
            'timeIn': FieldValue.serverTimestamp(),
            'recordId': recordId(orgName),
          });
        } else {
          transaction.set(entryRef, values);
        }
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid checkOut(String orgName) async {
    try {
      final uid = actorUid;
      if (uid == null) throw StateError('Sign in first.');
      await _firestore.runTransaction((transaction) async {
        final ref = entries.doc(entryId(orgName, uid));
        final entry = await transaction.get(ref);
        if (!entry.exists || entry.data()?['status'] != 'signed')
          throw StateError('Check in before checking out.');
        if (entry.data()?['timeOut'] != null) return;
        transaction.update(ref, {'timeOut': FieldValue.serverTimestamp()});
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  Stream<Map<String, dynamic>?> watchDay(String orgName) =>
      records.doc(recordId(orgName)).snapshots().map((s) => s.data());
  Stream<List<Map<String, dynamic>>> watchDayEntries(String orgName) => entries
      .where('organisationName', isEqualTo: orgName)
      .where('dayKey', isEqualTo: dayKey)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
  Stream<List<Map<String, dynamic>>> watchEmployeeEntries(
    String orgName,
    String uid,
  ) => entries
      .where('organisationName', isEqualTo: orgName)
      .where('employeeId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  Future<String> _employeeOrg(String employeeId) async {
    final user = await _firestore.collection('users').doc(employeeId).get();
    final org = user.data()?['organisation'] as String? ?? '';
    if (org.isEmpty)
      throw StateError('Employee does not belong to an organisation.');
    return org;
  }

  FutureVoid markAttendance(String employeeId) async {
    try {
      return await signAttendance(employeeId, await _employeeOrg(employeeId));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid markAttendanceAsNever(String employeeId) async {
    try {
      return await signAttendance(
        employeeId,
        await _employeeOrg(employeeId),
        absent: true,
      );
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid updateAtendancePresent(String id) => markAttendance(id);
  FutureVoid updateAtendanceEarlyOrLate(String id) => markAttendance(id);
  FutureVoid updateAttendanceAbsent(String id) => markAttendanceAsNever(id);
  FutureVoid clearAttendance(String id) => markAttendanceAsNever(id);

  Stream<AttendanceRecordModel> getAttendanceRecord({
    required String orgName,
  }) => records.doc(recordId(orgName)).snapshots().map((event) {
    if (!event.exists)
      throw StateError('Attendance has not been opened for today.');
    return AttendanceRecordModel.fromMap(event.data()!);
  });
  Stream<List<AttendanceRecordModel>> getListAttendanceRecords(
    String orgName,
  ) => records
      .where('organisationName', isEqualTo: orgName)
      .snapshots()
      .map(
        (event) => event.docs
            .map((doc) => AttendanceRecordModel.fromMap(doc.data()))
            .toList(),
      );
  Stream<List<AttendanceModel>> _list(String orgName, String status) => entries
      .where('organisationName', isEqualTo: orgName)
      .where('dayKey', isEqualTo: dayKey)
      .where('status', isEqualTo: status)
      .snapshots()
      .map(
        (event) => event.docs
            .map((doc) => AttendanceModel.fromMap(doc.data()))
            .toList(),
      );
  Stream<List<AttendanceModel>> getAttendanceList(String orgName) =>
      _list(orgName, 'notsigned');
  Stream<List<AttendanceModel>> getAttendanceListSigned(String orgName) =>
      _list(orgName, 'signed');
}
