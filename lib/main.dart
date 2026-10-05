import 'package:stark/core/providers/firebase_provider.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:stark/emulator_setup.dart';
import 'package:stark/core/local_demo/prepare.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:stark/core/app_navigation.dart';
import 'package:stark/features/auth/controllers/auth_controller.dart';
import 'package:stark/features/auth/views/sign_up_view.dart';
import 'package:stark/firebase_options.dart';
import 'package:stark/models/user_model.dart';
import 'package:stark/router.dart';
import 'package:stark/utils/error_text.dart';
import 'package:stark/utils/loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (const bool.fromEnvironment('LOCAL_DEMO')) prepareLocalEmulator();
    final options = localDemo ? null : DefaultFirebaseOptions.currentPlatform;
    if (options != null && options.projectId != ownedFirebaseProjectId)
      throw StateError(
        'Generate Firebase configuration for stark-282e6 before starting a live build.',
      );
    await Firebase.initializeApp(
      name: localDemo ? demoAppName : null,
      options: const bool.fromEnvironment('LOCAL_DEMO')
          ? const FirebaseOptions(
              apiKey: 'demo-stark-local-key',
              appId: '1:123:web:demo',
              messagingSenderId: '123',
              projectId: 'demo-stark',
              storageBucket: 'demo-stark.appspot.com',
            )
          : options,
    );
    if (const bool.fromEnvironment('LOCAL_DEMO')) {
      await authService.useAuthEmulator('127.0.0.1', 9099);
      if (kIsWeb) await authService.setPersistence(Persistence.NONE);
      await authService.signOut();
      firestoreService.useFirestoreEmulator('127.0.0.1', 8090);
      await storageService.useStorageEmulator('127.0.0.1', 9199);
      await seedLocalDemo().timeout(const Duration(seconds: 25));
      if (kIsWeb) WidgetsBinding.instance.ensureSemantics();
    }
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                const bool.fromEnvironment('LOCAL_DEMO')
                    ? 'Local demo startup failed. Check that the Firebase emulators are running.\n$error'
                    : 'Stark could not connect. Please try again.',
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authStateChangeProvider);
    ref.listen<AsyncValue<User?>>(authStateChangeProvider, (_, next) {
      next.whenData((user) {
        if (user == null) ref.read(userProvider.notifier).state = null;
      });
    });
    return state.when(
      data: (user) => user == null
          ? const SessionRouter()
          : ProfileGate(key: ValueKey(user.uid), user: user),
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (_, __) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Unable to load your session. Please reload.'),
          ),
        ),
      ),
    );
  }
}

class ProfileGate extends ConsumerStatefulWidget {
  final User user;
  const ProfileGate({super.key, required this.user});
  @override
  ConsumerState<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends ConsumerState<ProfileGate> {
  StreamSubscription<UserModel>? subscription;
  UserModel? profile;
  String? error;
  @override
  void initState() {
    super.initState();
    subscription = ref
        .read(authControllerProvider.notifier)
        .getUserData(widget.user.uid)
        .listen(
          (value) {
            if (!mounted) return;
            ref.read(userProvider.notifier).state = value;
            setState(() {
              profile = value;
              error = null;
            });
          },
          onError: (_) {
            if (mounted)
              setState(() {
                error =
                    'Your profile could not be loaded. Check your connection or sign out.';
              });
          },
        );
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (profile != null) return SessionRouter(profile: profile);
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!),
                    TextButton(
                      onPressed: () => authService.signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class SessionRouter extends StatefulWidget {
  final UserModel? profile;
  const SessionRouter({super.key, this.profile});
  @override
  State<SessionRouter> createState() => _SessionRouterState();
}

class _SessionRouterState extends State<SessionRouter> {
  late final router = buildAppRouter(widget.profile);
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: false,
    builder: (context, _) => MaterialApp.router(
      title: 'Stark — Employee Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff53b66e)),
      ),
      builder: (context, child) => localDemo
          ? Column(
              children: [
                const Material(
                  color: Color(0xffe6f4eb),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          'Local demo · fictional employees · Firebase emulators',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff22583a),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: child ?? const SizedBox()),
              ],
            )
          : child ?? const SizedBox(),
      routerConfig: router,
    ),
  );
}
