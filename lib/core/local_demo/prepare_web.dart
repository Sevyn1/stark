import 'dart:html' as html;

// Legacy FlutterFire caches this marker even when the Firebase JS app has been
// recreated. Clear only the emulator marker so useAuthEmulator reconnects it.
void prepareLocalEmulator() {
  html.window.sessionStorage.remove('firebaseEmulatorOrigin');
}
