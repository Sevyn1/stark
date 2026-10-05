# Stark — Employee Management

A Flutter application combining the earlier Employee Management account/onboarding interface with Stark's employee, project, task, attendance and conversation workflows.

**Flutter 3.47.2 · Dart 3 · Firebase Auth · Firestore · Storage · Riverpod · GoRouter**

## Run the local app

The local setup uses the `demo-stark` Firebase emulator project and fictional accounts. It does not require access to a real company's Firebase project.

Prerequisites: Flutter 3.47.2, Java 17 and Firebase CLI (`firebase-tools@13.35.1` was used for the emulator review). iOS builds additionally require Xcode and CocoaPods. The iOS deployment target is 15.0.

```sh
firebase emulators:start --project demo-stark --config firebase.demo.json --only auth,firestore,storage
```

In another terminal, run on an iPhone simulator:

```sh
flutter pub get
flutter run -d <simulator-device-id> --dart-define=LOCAL_DEMO=true
```

Or run the browser preview:

```sh
flutter build web --dart-define=LOCAL_DEMO=true --pwa-strategy=none
python3 scripts/prepare_web_preview.py
python3 -m http.server 8086 --bind 127.0.0.1 --directory build/web
```

Open http://127.0.0.1:8086/. The preview initially signs in as the sample manager. Sign out to try onboarding or another account.

| Account | Email |
|---|---|
| Manager, Alex Morgan | alex.manager@example.test |
| Employee, Jamie Lee | jamie.employee@example.test |
| Employee, Taylor Rivera | taylor.employee@example.test |
| Employee available to invite, Sam Reed | sam.invitee@example.test |

All fixture accounts use **StarkDemo123!**, a public development password for the emulator only. Fixtures are created when absent; normal profile edits and accepted invitations remain in the running emulator. The emulator data is temporary unless you explicitly export it. Each account has one active workspace.

## Application workflows

- Manager and employee registration, validated sign-in, sign-out, recovery-link requests and email-verification requests/status checks.
- Manager workspace creation with membership and chat metadata committed together.
- Search eligible employees, send invitations, accept/reject invitations, view members and remove an employee.
- Create projects, assign tasks to existing workspace members, update task status, complete projects after their tasks are done and reopen completed projects.
- Open organisation-specific daily attendance, sign employees, see present/absent and early/late totals, and retain previous days.
- Team text messages, replies and image attachments up to 5 MB. Failed text sends retain the draft. The unfinished microphone and camera controls were replaced with working text/image actions.
- Edit names, job title, phone and profile photo. These updates cannot overwrite account IDs, manager authority or workspace membership through the profile repository.

The demo uses the application's Firebase repositories, not a separate mock dashboard. Photo and chat uploads target the local Storage emulator. Reset and verification requests in emulator mode produce local action links; they do not send real emails.

## Engineering changes

The review fixes writes that previously reported success before completion, cross-organisation/day attendance collisions, employee search against the wrong collection, stale profile/session handling, invalid empty-employee task forms and clipped task submission controls. Projects and tasks use organisation-scoped identifiers. Task names remain unique within a workspace.

The SDK and dependencies were migrated from the recovered Flutter 3.7/Dart 2 environment. Navigation now uses GoRouter; icons use Flutter's supported IconData type; file picking uses the current cross-platform byte-reading API. iOS uses CocoaPods through an app-specific setting rather than changing the user's global Flutter configuration.

## Verification and deployment boundaries

```sh
flutter test --reporter expanded
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build web --dart-define=LOCAL_DEMO=true --pwa-strategy=none
```

The regression suite covers application data workflows, membership writes, duplicates, task assignment, scoped records, attendance history/idempotency, protected profile fields and message persistence. Fake Firestore tests do not simulate real transaction contention or production security rules. Browser/native verification results are recorded separately as they are completed.

The `*.demo.rules` files are emulator-only convenience rules. Do not deploy them as production rules. A live build requires your own Firebase configuration and reviewed rules, permissions and indexes. No live deployment, real employee data, production authentication audit or physical-device test is claimed by the local demonstration.

Existing production-format records with the previous global project/task/attendance keys require a reviewed migration before use; the fixture migration only applies to the known local sample records. Android and desktop builds are not claimed as verified.

## Source history

Stark retains its existing fork relationship, contributor history and recovered source credits. The user requested consolidation of their earlier private Employee Management UI repository. Its useful artwork, onboarding components and account designs were integrated into connected workflows; inactive pretend OTP/success screens and the empty home page were replaced. See [merge provenance](docs/MERGE_PROVENANCE.md).

October 2026 integration, SDK migration and maintenance were developed with Codex assistance, directed and reviewed by Favour Ojo. This does not establish sole authorship of the shared project or backdate current work to the original course/project year.
