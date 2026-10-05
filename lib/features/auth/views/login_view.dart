import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stark/core/app_navigation.dart';
import '../controllers/auth_controller.dart';
import '../../onboarding/widgets/account_header.dart';

/// Consolidated account form: prototype styling with Stark authentication.
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});
  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final email = TextEditingController();
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Sign in')),
        body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Form(
                    key: form,
                    child: Column(children: [
                      const AccountHeader(subtitle: 'Login to your account'),
                      const SizedBox(height: 28),
                      if (const bool.fromEnvironment('LOCAL_DEMO'))
                        const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                                'Demo manager: alex.manager@example.test\nDemo employee: jamie.employee@example.test\nPassword: StarkDemo123!')),
                      TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration:
                              const InputDecoration(labelText: 'Email address'),
                          validator: (s) => s != null &&
                                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(s.trim())
                              ? null
                              : 'Enter a valid email address'),
                      const SizedBox(height: 18),
                      TextFormField(
                          controller: password,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                          validator: (s) => s == null || s.isEmpty
                              ? 'Enter your password'
                              : null),
                      const SizedBox(height: 24),
                      ElevatedButton(
                          onPressed: busy
                              ? null
                              : () {
                                  if (form.currentState!.validate())
                                    ref
                                        .read(authControllerProvider.notifier)
                                        .loginAdmin(
                                            context: context,
                                            email:
                                                email.text.trim().toLowerCase(),
                                            password: password.text);
                                },
                          child: Text(busy ? 'Signing in…' : 'Sign in')),
                      TextButton(
                          onPressed: busy
                              ? null
                              : () => AppNavigator.of(context).push('/recovery'),
                          child: const Text('Forgot password?')),
                      TextButton(
                          onPressed: busy
                              ? null
                              : () =>
                                  AppNavigator.of(context).push('/select-role'),
                          child: const Text('Create an account')),
                    ])),
              )),
        ));
  }
}
