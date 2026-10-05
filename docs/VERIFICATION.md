# Verification record — October 2026

## Completed checks

- The pre-migration repository regression suite passed under Flutter 3.7.12.
- Following the Flutter 3.47.2/Dart 3 migration, 18 repository regression cases passed. Fake Firestore 4 queues some transaction notifications; stream assertions wait for the expected notification rather than claiming a real commit timing test.
- A modern browser build passed after navigation, icon and file-picker migration.
- Static analysis completed without errors; legacy style/deprecation diagnostics remain and are not suppressed in source.
- In the running browser, opening today's attendance created both employee entries. Signing Jamie changed the dashboard to Present 1, Absent 1, Late 1; the two-employee total remained consistent.
- Browser inspection found the original task form's submit action clipped below the viewport. Its container is now bounded to the available height, allowing its inner scroll view to reach all fields/actions. In the rebuilt preview, the form scrolled to its submit button. A Check inbox task was submitted for Jamie and the dialog closed on success.

## Native build audit (in progress)

- Installed missing CocoaPods through Homebrew.
- Updated old iOS 9/11 deployment settings to iOS 15 for the current Xcode installation.
- The old Flutter/Firebase build failed in outdated Swift dependencies and generated signing metadata. An isolated build copy was used to avoid synchronised-folder metadata.
- The project was migrated to Flutter 3.47.2, current Firebase/plugin packages and CocoaPods integration. The modern native debug simulator build completed successfully and produced Runner.app. The simulator GUI is unavailable, so no native visual/physical-device run is claimed.
- The installed Xcode developer directory does not contain the Simulator GUI application at its usual path; native GUI access could not locate it. Native rendering has not been inferred from a browser screenshot.

## Limits

The local project ID is demo-stark. Auth, Firestore and Storage all use loopback emulators. No recovered live Firebase project or real employee records were used. Demo rules are not production rules. No physical-device, App Store, Android, deployment or production security claim is made.
