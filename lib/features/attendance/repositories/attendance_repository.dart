import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:stark/core/failure.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/core/type_defs.dart';
import 'package:stark/models/attemdance_model.dart';
import 'package:stark/models/attendance_record_model.dart';

final attendanceRepositoryProvider = Provider(
    (ref) => AttendanceRepository(firestore: ref.watch(firestoreProvider)));

/// Daily organisation-scoped attendance; counts and employee entries commit together.
class AttendanceRepository {
  final FirebaseFirestore _firestore;
  final DateTime Function() _now;
  AttendanceRepository(
      {required FirebaseFirestore firestore, DateTime Function()? now})
      : _firestore = firestore,
        _now = now ?? DateTime.now;
  String get dayKey {
    final d = _now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String recordId(String org) => '${Uri.encodeComponent(org)}::$dayKey';
  String entryId(String org, String employee) => '${recordId(org)}::$employee';
  CollectionReference<Map<String, dynamic>> get records =>
      _firestore.collection('attendanceRecords');
  CollectionReference<Map<String, dynamic>> get entries =>
      _firestore.collection('attendance');

  FutureVoid createAttendance(
      AttendanceModel attendance, String orgName) async {
    try {
      if (orgName.isEmpty) throw StateError('Choose an organisation first.');
      await _firestore.runTransaction((transaction) async {
        final org = await transaction
            .get(_firestore.collection('organisations').doc(orgName));
        final record = await transaction.get(records.doc(recordId(orgName)));
        if (!org.exists) throw StateError('Organisation not found');
        if (record.exists)
          return; // Opening again must not erase today's sign-ins.
        final members = List<String>.from(org.data()!['employees'] ?? []);
        if (members.length > 450)
          throw StateError(
              'This attendance workflow supports up to 450 employees.');
        for (final employee in members) {
          transaction.set(entries.doc(entryId(orgName, employee)), {
            ...attendance
                .copyWith(
                    employeeId: employee,
                    organisationName: orgName,
                    status: 'notsigned')
                .toMap(),
            'dayKey': dayKey,
          });
        }
        transaction.set(records.doc(recordId(orgName)), {
          ...AttendanceRecordModel(
                  day: _now(),
                  organisationName: orgName,
                  early: [],
                  late: [],
                  present: [],
                  absent: members)
              .toMap(),
          'dayKey': dayKey,
        });
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid signAttendance(String employeeId, String orgName,
      {bool absent = false}) async {
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
          final time = entry.data()!['timeIn'] as int?;
          final signedAt =
              time == null ? now : DateTime.fromMillisecondsSinceEpoch(time);
          (signedAt.isBefore(DateTime(now.year, now.month, now.day, 9))
                  ? early
                  : late)
              .add(employeeId);
        }
        transaction.update(entryRef, {
          'status': absent ? 'neversigned' : 'signed',
          'timeIn': absent
              ? null
              : entry.data()!['timeIn'] ?? now.millisecondsSinceEpoch
        });
        transaction.update(recordRef, {
          'present': present,
          'absent': missing,
          'early': early,
          'late': late
        });
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

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
      return await signAttendance(employeeId, await _employeeOrg(employeeId),
          absent: true);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid updateAtendancePresent(String id) => markAttendance(id);
  FutureVoid updateAtendanceEarlyOrLate(String id) => markAttendance(id);
  FutureVoid updateAttendanceAbsent(String id) => markAttendanceAsNever(id);
  FutureVoid clearAttendance(String id) => markAttendanceAsNever(id);

  Stream<AttendanceRecordModel> getAttendanceRecord(
          {required String orgName}) =>
      records.doc(recordId(orgName)).snapshots().map((event) {
        if (!event.exists)
          throw StateError('Attendance has not been opened for today.');
        return AttendanceRecordModel.fromMap(event.data()!);
      });
  Stream<List<AttendanceRecordModel>> getListAttendanceRecords(
          String orgName) =>
      records.where('organisationName', isEqualTo: orgName).snapshots().map(
          (event) => event.docs
              .map((doc) => AttendanceRecordModel.fromMap(doc.data()))
              .toList());
  Stream<List<AttendanceModel>> _list(String orgName, String status) => entries
      .where('organisationName', isEqualTo: orgName)
      .where('dayKey', isEqualTo: dayKey)
      .where('status', isEqualTo: status)
      .snapshots()
      .map((event) => event.docs
          .map((doc) => AttendanceModel.fromMap(doc.data()))
          .toList());
  Stream<List<AttendanceModel>> getAttendanceList(String orgName) =>
      _list(orgName, 'notsigned');
  Stream<List<AttendanceModel>> getAttendanceListSigned(String orgName) =>
      _list(orgName, 'signed');
}
