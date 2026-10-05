# Stark — Employee and Task Management

A Flutter/Firebase application organized around employee invitations, projects, task assignments, attendance and messaging. The source uses Riverpod state management, repository classes and Firestore streams.

**Dart · Flutter · Firebase Authentication · Firestore · Riverpod**

## Structure

- `lib/features/auth`: login/signup and account state.
- `lib/features/organisation` and `employee`: organisation membership and invitations.
- `lib/features/tasks_projects`: project creation, assignments and task status.
- `lib/features/attendance`: attendance records.
- `lib/features/messaging`: group messages and media-handling code.
- `lib/models`: serialized application records.

These describe implemented source areas; the full live Firebase application has not been independently verified in this review.

## Run and test

The recovered dependency set targets **Flutter 3.7.12 / Dart 2.19.6**. This pinned legacy environment was used for compatibility verification, not recommended as a current production platform. A supported-SDK migration is separate work.

```sh
flutter pub get
flutter test
flutter build web
```

Tests use `fake_cloud_firestore`; they do not read or change live Firebase data. To run the interactive application, create your own development Firebase project and regenerate `lib/firebase_options.dart` with FlutterFire. Do not use the recovered project configuration against real employee data. Firestore security rules and storage permissions require a separate review; no rules deployment is included here.

## Maintenance review — October 2026

- Project/task creation uses Firestore transactions to reject duplicates and keep task membership consistent.
- Invitation writes use atomic batches and complete before success is reported.
- Status writes are awaited, errors use the repository's `Either` result, and the ongoing-task query explicitly filters `ongoing`.
- Task form submission requires a task name, description and selected employee.
- The unrelated starter counter test was replaced by eight repository regression tests.

**Verification:** eight tests pass and the application compiles successfully for the web. Tests cover persistence before success, duplicates, missing projects, status queries, failed updates, invitation creation, acceptance and rejection. Fake Firestore tests do not prove production security-rule correctness, transaction contention behavior or end-to-end Firebase operation.

## Remaining design work

Project/task document IDs use names globally; multi-organisation name collisions need a data-model migration. Invitations are keyed by receiver ID, which limits simultaneous invitations. Some profile/messaging/attendance paths still require asynchronous error and authorization review. Dependencies and platform packages need modernization before deployment.

## Project history

This repository preserves its existing fork relationship and shared-project history. It does not establish sole authorship by Favour Ojo. The maintenance review was directed and reviewed by Favour with Codex assistance; the original source history and credits remain intact.
