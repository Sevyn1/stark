import 'package:stark/features/auth/controllers/auth_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:stark/core/constants/firebase_constants.dart';
import 'package:stark/core/failure.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/core/type_defs.dart';
import 'package:stark/models/project_model.dart';
import 'package:stark/models/task_model.dart';

//! the tasksProject repo provider
final tasksProjectRepositoryProvider = Provider((ref) {
  return TaskProjectRepository(
    firestore: ref.watch(firestoreProvider),
    organisationName: ref.watch(userProvider)?.organisation,
    actorUid: ref.watch(userProvider)?.uid,
  );
});

//!  tasksProject repo class
class TaskProjectRepository {
  final FirebaseFirestore _firestore;
  final String? organisationName;
  final String? actorUid;
  TaskProjectRepository({
    required FirebaseFirestore firestore,
    this.organisationName,
    this.actorUid,
  }) : _firestore = firestore;
  String _id(String name) => organisationName == null
      ? name
      : '${Uri.encodeComponent(organisationName!)}::${Uri.encodeComponent(name)}';
  Query _scoped(CollectionReference collection) => organisationName == null
      ? collection
      : collection.where('organisationName', isEqualTo: organisationName);
  void _validate(String name, String org) {
    if (name.trim().isEmpty || name.length > 100 || name.contains('/'))
      throw ArgumentError('Enter a name of 1–100 characters without slashes.');
    if (organisationName != null && (org.isEmpty || org != organisationName))
      throw StateError('Choose your organisation first.');
  }

  //! create project
  FutureVoid createProject(ProjectModel project) async {
    try {
      _validate(project.name, project.organisationName);
      if (actorUid != null && project.managerId != actorUid)
        throw StateError('Only your manager account can create this project.');
      await _firestore.runTransaction((transaction) async {
        final reference = _projects.doc(_id(project.name));
        final snapshot = await transaction.get(reference);
        if (actorUid != null) {
          final org = await transaction.get(
            _organisations.doc(project.organisationName),
          );
          if (!((org.data() as Map<String, dynamic>?)?['managers'] as List? ??
                  [])
              .contains(actorUid))
            throw StateError(
              'Only this organisation’s manager can create projects.',
            );
        }
        if (snapshot.exists)
          throw StateError('Project with the same name exists');
        transaction.set(reference, project.toMap());
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid createTask(TaskModel task) async {
    try {
      _validate(task.taskName, task.organisationName);
      if (task.description.trim().isEmpty || task.employeeId.isEmpty)
        throw ArgumentError("Choose an employee and enter a task description.");
      await _firestore.runTransaction((transaction) async {
        final taskReference = _tasks.doc(_id(task.taskName));
        final projectReference = _projects.doc(_id(task.projectName));
        final existingTask = await transaction.get(taskReference);
        final project = await transaction.get(projectReference);
        if (existingTask.exists)
          throw StateError('Task with the same name exists');
        if (!project.exists) throw StateError('Project does not exist');
        if (organisationName != null) {
          final employee = await transaction.get(
            _firestore.collection('users').doc(task.employeeId),
          );
          final org = await transaction.get(
            _organisations.doc(task.organisationName),
          );
          final data = employee.data();
          if (actorUid != null &&
              (task.managerId != actorUid ||
                  (project.data() as Map<String, dynamic>)['managerId'] !=
                      actorUid ||
                  !((org.data() as Map<String, dynamic>?)?['managers']
                              as List? ??
                          [])
                      .contains(actorUid)))
            throw StateError('Only the project manager can assign tasks.');
          if ((project.data() as Map<String, dynamic>)['status'] == 'done')
            throw StateError('Reopen the project before assigning new tasks.');
          if (!employee.exists ||
              data?['organisation'] != task.organisationName ||
              data?['isAdmin'] != false ||
              !((org.data() as Map<String, dynamic>?)?['employees'] as List? ??
                      [])
                  .contains(task.employeeId)) {
            throw StateError(
              'Assign tasks only to employees in this organisation.',
            );
          }
        }
        transaction.update(projectReference, {
          'employeeIds': FieldValue.arrayUnion([task.employeeId]),
          'taskIds': FieldValue.arrayUnion([task.taskName]),
        });
        transaction.set(taskReference, task.toMap());
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  //! get projects per organisation
  Stream<List<ProjectModel>> getProjectsForOrganisation(String orgName) {
    return _scoped(
      _projects,
    ).where('organisationName', isEqualTo: orgName).snapshots().map((event) {
      List<ProjectModel> projects = [];
      for (var doc in event.docs) {
        projects.add(ProjectModel.fromMap(doc.data() as Map<String, dynamic>));
      }
      return projects;
    });
  }

  //! get projects for an employee
  Stream<List<ProjectModel>> getProjectsForEmployee(String employeeId) {
    return _scoped(
      _projects,
    ).where('employeeIds', arrayContains: employeeId).snapshots().map((event) {
      List<ProjectModel> projects = [];
      for (var doc in event.docs) {
        projects.add(ProjectModel.fromMap(doc.data() as Map<String, dynamic>));
      }
      return projects;
    });
  }

  //! get tasks for an employee
  Stream<List<TaskModel>> getTasksForEmployee(String employeeId) {
    return _scoped(
      _tasks,
    ).where('employeeId', isEqualTo: employeeId).snapshots().map((event) {
      List<TaskModel> tasks = [];
      for (var doc in event.docs) {
        tasks.add(TaskModel.fromMap(doc.data() as Map<String, dynamic>));
      }
      return tasks;
    });
  }

  //! get tasks in projects
  Stream<List<TaskModel>> getTasksInProjects(String projectName) {
    return _scoped(
      _tasks,
    ).where('projectName', isEqualTo: projectName).snapshots().map((event) {
      List<TaskModel> tasks = [];
      for (var doc in event.docs) {
        tasks.add(TaskModel.fromMap(doc.data() as Map<String, dynamic>));
      }
      return tasks;
    });
  }

  //! get tasks in projects
  Stream<List<TaskModel>> getOngoingTasksInProjects(String projectName) {
    return _scoped(_tasks)
        .where('projectName', isEqualTo: projectName)
        .where('status', isEqualTo: 'ongoing')
        .snapshots()
        .map((event) {
          List<TaskModel> tasks = [];
          for (var doc in event.docs) {
            tasks.add(TaskModel.fromMap(doc.data() as Map<String, dynamic>));
          }
          return tasks;
        });
  }

  //! get particular project
  Stream<ProjectModel> getParticularProject(String projectName) {
    return _projects
        .doc(_id(projectName))
        .snapshots()
        .map(
          (event) => ProjectModel.fromMap(event.data() as Map<String, dynamic>),
        );
  }

  //! get particular task
  Stream<TaskModel> getParticularTask(String taskName) {
    return _tasks
        .doc(_id(taskName))
        .snapshots()
        .map(
          (event) => TaskModel.fromMap(event.data() as Map<String, dynamic>),
        );
  }

  FutureVoid _setStatus(
    CollectionReference collection,
    String name,
    String status, {
    bool task = false,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reference = collection.doc(_id(name));
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) throw StateError('Record no longer exists.');
        final data = snapshot.data() as Map<String, dynamic>;
        if (actorUid != null &&
            data['managerId'] != actorUid &&
            !(task && data['employeeId'] == actorUid)) {
          throw StateError('You do not have access to change this record.');
        }
        if (!task && status == 'done') {
          for (final taskName in List<String>.from(data['taskIds'] ?? [])) {
            final item = await transaction.get(_tasks.doc(_id(taskName)));
            if (!item.exists ||
                (item.data() as Map<String, dynamic>)['status'] != 'done')
              throw StateError(
                'Complete all tasks before completing the project.',
              );
          }
        }
        if (task && status == 'ongoing') {
          final project = await transaction.get(
            _projects.doc(_id(data['projectName'] as String)),
          );
          if (project.exists &&
              (project.data() as Map<String, dynamic>)['status'] == 'done')
            throw StateError('Ask the manager to reopen the project first.');
        }
        transaction.update(reference, {'status': status});
      });
      return right(null);
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid updateProjectStatusDone(String name) =>
      _setStatus(_projects, name, 'done');
  FutureVoid updateProjectStatusProgress(String name) =>
      _setStatus(_projects, name, 'ongoing');
  FutureVoid updateTaskStatusDone(String name) =>
      _setStatus(_tasks, name, 'done', task: true);
  FutureVoid updateTaskStatusProgress(String name) =>
      _setStatus(_tasks, name, 'ongoing', task: true);

  CollectionReference get _organisations =>
      _firestore.collection(FirebaseConstants.organisationsCollection);

  CollectionReference get _projects =>
      _firestore.collection(FirebaseConstants.projectsCollection);

  CollectionReference get _tasks =>
      _firestore.collection(FirebaseConstants.tasksCollection);
}
