import 'package:stark/features/tasks_projects/repositories/task_project_repository.dart';
import 'package:stark/models/project_model.dart';
import 'package:stark/models/task_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:stark/features/attendance/repositories/attendance_repository.dart';
import 'package:stark/features/organisation/repositories/organisation_repository.dart';
import 'package:stark/features/profile/repositories/profile_repository.dart';
import 'package:stark/models/attemdance_model.dart';
import 'package:stark/models/organisation_model.dart';
import 'package:stark/models/org_message_model.dart';
import 'package:stark/models/user_model.dart';

void main() {
  test(
      'Organisation creation commits membership and chat together and rejects duplicate',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('manager').set({'organisation': '', 'isAdmin': true});
    final repo = OrganisationsRepository(firestore: db);
    const org = OrganisationModel(
        id: 'A',
        name: 'A',
        avatar: '',
        description: '',
        managers: ['manager'],
        employees: [],
        prospectiveEmployees: []);
    final chat = OrgMessagingModel(
        senderId: 'manager',
        name: 'A',
        groupId: 'A',
        lastMessage: '',
        groupPic: '',
        membersUid: ['manager'],
        timeSent: DateTime(2026));
    expect(
        (await repo.createOrganisation(org, 'manager', messaging: chat))
            .isRight(),
        true);
    expect(
        (await db.collection('users').doc('manager').get())
            .data()!['organisation'],
        'A');
    expect((await db.collection('messageGroup').doc('A').get()).exists, true);
    expect(
        (await repo.createOrganisation(org, 'manager', messaging: chat))
            .isLeft(),
        true);
  });
  test('Missing manager rolls back organisation and chat creation', () async {
    final db = FakeFirebaseFirestore();
    final repo = OrganisationsRepository(firestore: db);
    const org = OrganisationModel(
        id: 'A',
        name: 'A',
        avatar: '',
        description: '',
        managers: ['missing'],
        employees: [],
        prospectiveEmployees: []);
    expect((await repo.createOrganisation(org, 'missing')).isLeft(), true);
    expect((await db.collection('organisations').get()).docs, isEmpty);
  });
  test('Employee search uses user records and lower-case prefix', () async {
    final db = FakeFirebaseFirestore();
    await db
        .collection('users')
        .doc('one')
        .set({'uid': 'one', 'isAdmin': false, 'email': 'jamie@example.test'});
    await db
        .collection('users')
        .doc('manager')
        .set({'uid': 'manager', 'isAdmin': true, 'email': 'jane@example.test'});
    final matches = await OrganisationsRepository(firestore: db)
        .searchForEmployees(' JA ')
        .first;
    expect(matches.map((u) => u.uid), ['one']);
  });
  test('Editable profile fields cannot overwrite role authority or membership',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u').set({
      'uid': 'u',
      'isAdmin': false,
      'organisation': 'A',
      'email': 'real@example.test'
    });
    const edited = UserModel(
        uid: 'u',
        firstName: '  Jamie ',
        lastName: 'Lee',
        profilePic: '',
        email: 'changed@example.test',
        isAdmin: true,
        organisation: 'B',
        role: 'Developer',
        phone: '');
    expect(
        (await UserProfileRepository(firestore: db).editProfile(edited))
            .isRight(),
        true);
    final stored = (await db.collection('users').doc('u').get()).data()!;
    expect(stored['firstName'], 'Jamie');
    expect(stored['isAdmin'], false);
    expect(stored['organisation'], 'A');
    expect(stored['email'], 'real@example.test');
  });
  test('Attendance isolates organisations and sign-in counts are idempotent',
      () async {
    final db = FakeFirebaseFirestore();
    for (final org in ['A', 'B'])
      await db.collection('organisations').doc(org).set({
        'employees': ['one', 'two']
      });
    final repo = AttendanceRepository(
        firestore: db, now: () => DateTime(2026, 10, 5, 10));
    for (final org in ['A', 'B'])
      expect(
          (await repo.createAttendance(
                  AttendanceModel(
                      employeeId: '',
                      timeIn: null,
                      status: 'notsigned',
                      organisationName: org),
                  org))
              .isRight(),
          true);
    expect((await repo.signAttendance('one', 'A')).isRight(), true);
    expect((await repo.signAttendance('one', 'A')).isRight(), true);
    final a = await repo.getAttendanceRecord(orgName: 'A').first;
    final b = await repo.getAttendanceRecord(orgName: 'B').first;
    expect(a.present, ['one']);
    expect(a.late, ['one']);
    expect(a.absent, ['two']);
    expect(b.present, isEmpty);
    expect(b.absent, ['one', 'two']);
    await repo.createAttendance(
        const AttendanceModel(
            employeeId: '',
            timeIn: null,
            status: 'notsigned',
            organisationName: 'A'),
        'A');
    expect(
        (await repo.getAttendanceRecord(orgName: 'A').first).present, ['one']);
  });
  test('New day preserves yesterday and cannot sign unopened attendance',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('organisations').doc('A').set({
      'employees': ['one']
    });
    var day = DateTime(2026, 10, 5, 8);
    final repo = AttendanceRepository(firestore: db, now: () => day);
    await repo.createAttendance(
        const AttendanceModel(
            employeeId: '',
            timeIn: null,
            status: 'notsigned',
            organisationName: 'A'),
        'A');
    await repo.signAttendance('one', 'A');
    day = DateTime(2026, 10, 6, 8);
    expect((await repo.signAttendance('one', 'A')).isLeft(), true);
    await repo.createAttendance(
        const AttendanceModel(
            employeeId: '',
            timeIn: null,
            status: 'notsigned',
            organisationName: 'A'),
        'A');
    expect((await repo.getListAttendanceRecords('A').first).length, 2);
    expect(
        (await repo.getAttendanceRecord(orgName: 'A').first).present, isEmpty);
  });
  test('Same project names in two organisations remain independent', () async {
    final db = FakeFirebaseFirestore();
    ProjectModel project(String org) => ProjectModel(
        organisationName: org,
        managerId: 'manager',
        name: 'Portal',
        employeeIds: [],
        taskIds: [],
        status: 'ongoing',
        type: '',
        startDateTime: DateTime(2026),
        endDateTime: DateTime(2027));
    final a = TaskProjectRepository(firestore: db, organisationName: 'A');
    final b = TaskProjectRepository(firestore: db, organisationName: 'B');
    expect((await a.createProject(project('A'))).isRight(), true);
    expect((await b.createProject(project('B'))).isRight(), true);
    (await a.updateProjectStatusDone('Portal')).fold((failure) => fail(failure.message), (_) {});
    expect((await a.getParticularProject('Portal').firstWhere((value) => value.status == 'done').timeout(const Duration(seconds: 2))).status, 'done');
    expect((await b.getParticularProject('Portal').first).status, 'ongoing');
  });
  test(
      'Task assignment rejects an employee from another organisation without writes',
      () async {
    final db = FakeFirebaseFirestore();
    await db
        .collection('users')
        .doc('employee')
        .set({'isAdmin': false, 'organisation': 'B'});
    await db.collection('organisations').doc('A').set({'employees': []});
    final repo = TaskProjectRepository(firestore: db, organisationName: 'A');
    await repo.createProject(ProjectModel(
        organisationName: 'A',
        managerId: 'm',
        name: 'Portal',
        employeeIds: [],
        taskIds: [],
        status: 'ongoing',
        type: '',
        startDateTime: DateTime(2026),
        endDateTime: DateTime(2027)));
    expect(
        (await repo.createTask(const TaskModel(
                taskName: 'Review',
                projectName: 'Portal',
                employeeId: 'employee',
                description: 'Check API',
                organisationName: 'A',
                status: 'ongoing',
                managerId: 'm')))
            .isLeft(),
        true);
    expect((await db.collection('tasks').get()).docs, isEmpty);
    expect((await repo.getParticularProject('Portal').first).taskIds, isEmpty);
  });
}
