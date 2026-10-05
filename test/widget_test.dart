import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark/features/tasks_projects/repositories/task_project_repository.dart';
import 'package:stark/features/employee/repositories/employee_repository.dart';
import 'package:stark/models/project_model.dart';
import 'package:stark/models/task_model.dart';
import 'package:stark/models/invite_model.dart';

void main() {
  late FakeFirebaseFirestore db;
  late TaskProjectRepository tasks;
  late EmployeeRepository employees;
  ProjectModel project() => ProjectModel(
      organisationName: 'demo',
      managerId: 'manager',
      name: 'Project',
      employeeIds: [],
      taskIds: [],
      status: 'ongoing',
      type: 'demo',
      startDateTime: DateTime(2024),
      endDateTime: DateTime(2024, 2));
  TaskModel task(String projectName) => TaskModel(
      taskName: 'Task',
      projectName: projectName,
      employeeId: 'member',
      description: 'Fictional task',
      organisationName: 'demo',
      status: 'not started',
      managerId: 'manager');
  InviteModel invite() => InviteModel(
      organisationName: 'demo',
      receiverId: 'member',
      managerId: 'manager',
      sentAt: DateTime(2024),
      actionAt: DateTime(2024),
      status: 'pending');
  setUp(() {
    db = FakeFirebaseFirestore();
    tasks = TaskProjectRepository(firestore: db);
    employees = EmployeeRepository(firestore: db);
  });
  test('Project persists before success and duplicate is rejected', () async {
    expect((await tasks.createProject(project())).isRight(), isTrue);
    expect(
        (await db.collection('projects').doc('Project').get()).exists, isTrue);
    expect((await tasks.createProject(project())).isLeft(), isTrue);
  });
  test('Task writes membership and rejects duplicates', () async {
    await tasks.createProject(project());
    expect((await tasks.createTask(task('Project'))).isRight(), isTrue);
    var data = (await db.collection('projects').doc('Project').get()).data()!;
    expect(data['taskIds'], ['Task']);
    expect(data['employeeIds'], ['member']);
    expect((await db.collection('tasks').doc('Task').get()).exists, isTrue);
    expect((await tasks.createTask(task('Project'))).isLeft(), isTrue);
  });
  test('Missing project creates no orphan task', () async {
    expect((await tasks.createTask(task('missing'))).isLeft(), isTrue);
    expect((await db.collection('tasks').doc('Task').get()).exists, isFalse);
  });
  test('Ongoing query reflects status transition', () async {
    await tasks.createProject(project());
    await tasks.createTask(task('Project'));
    await tasks.updateTaskStatusProgress('Task');
    expect(
        (await tasks.getOngoingTasksInProjects('Project').first)
            .map((t) => t.taskName),
        ['Task']);
    await tasks.updateTaskStatusDone('Task');
    expect(await tasks.getOngoingTasksInProjects('Project').first, isEmpty);
  });
  test('Missing status update returns failure', () async {
    expect((await tasks.updateTaskStatusDone('missing')).isLeft(), isTrue);
    expect((await tasks.updateProjectStatusDone('missing')).isLeft(), isTrue);
  });
  test('Send invite persists both related documents', () async {
    await db
        .collection('organisations')
        .doc('demo')
        .set({'prospectiveEmployees': [], 'employees': [], 'managers':['manager']});
    await db.collection('users').doc('member').set({'organisation':'','isAdmin':false});
    expect((await employees.sendInvite(invite(), 'demo')).isRight(), isTrue);
    expect((await db.collection('invites').doc('member').get()).exists, isTrue);
    expect(
        (await db.collection('organisations').doc('demo').get())
            .data()!['prospectiveEmployees'],
        ['member']);
  });
  test('Acceptance updates organisation, user, invite and group', () async {
    await db
        .collection('organisations')
        .doc('demo')
        .set({'prospectiveEmployees': [], 'employees': [], 'managers':['manager']});
    await db.collection('users').doc('member').set({'organisation': ''});
    await db.collection('messageGroup').doc('demo').set({'membersUid': []});
    await db.collection('users').doc('member').set({'organisation':'','isAdmin':false});
    await employees.sendInvite(invite(), 'demo');
    expect((await employees.acceptInvite(invite())).isRight(), isTrue);
    expect(
        (await db.collection('users').doc('member').get())
            .data()!['organisation'],
        'demo');
    expect(
        (await db.collection('organisations').doc('demo').get())
            .data()!['employees'],
        ['member']);
    expect(
        (await db.collection('messageGroup').doc('demo').get())
            .data()!['membersUid'],
        ['member']);
  });
  test('Rejection removes invite and prospective membership', () async {
    await db
        .collection('organisations')
        .doc('demo')
        .set({'prospectiveEmployees': [], 'employees': [], 'managers':['manager']});
    await db.collection('users').doc('member').set({'organisation':'','isAdmin':false});
    await employees.sendInvite(invite(), 'demo');
    expect((await employees.rejectInvite(invite())).isRight(), isTrue);
    expect(
        (await db.collection('invites').doc('member').get()).exists, isFalse);
    expect(
        (await db.collection('organisations').doc('demo').get())
            .data()!['prospectiveEmployees'],
        isEmpty);
  });
}
