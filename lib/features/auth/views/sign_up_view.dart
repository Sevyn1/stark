import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import '../../onboarding/widgets/account_header.dart';

class SignUpView extends ConsumerStatefulWidget {
  final String type;
  const SignUpView({super.key, required this.type});
  @override
  ConsumerState<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<SignUpView> {
  final form = GlobalKey<FormState>();
  final first = TextEditingController(),
      last = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  @override
  void dispose() {
    for (final c in [first, last, email, password, confirm]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    return Scaffold(
        appBar: AppBar(
            title: Text(widget.type == 'admin'
                ? 'Manager account'
                : 'Employee account')),
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Form(
                      key: form,
                      child: Column(children: [
                        const AccountHeader(subtitle: 'Create your account'),
                        const SizedBox(height: 24),
                        for (final entry
                            in {first: 'First name', last: 'Last name'}.entries)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: TextFormField(
                                  controller: entry.key,
                                  decoration:
                                      InputDecoration(labelText: entry.value),
                                  validator: (s) =>
                                      s == null || s.trim().isEmpty
                                          ? 'Enter ${entry.value.toLowerCase()}'
                                          : null)),
                        TextFormField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                                labelText: 'Email address'),
                            validator: (s) => s != null &&
                                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(s.trim())
                                ? null
                                : 'Enter a valid email address'),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: password,
                            obscureText: true,
                            decoration:
                                const InputDecoration(labelText: 'Password'),
                            validator: (s) => s == null || s.length < 8
                                ? 'Use at least 8 characters'
                                : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: confirm,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'Confirm password'),
                            validator: (s) => s != password.text
                                ? 'Passwords must match'
                                : null),
                        const SizedBox(height: 24),
                        ElevatedButton(
                            onPressed: busy
                                ? null
                                : () {
                                    if (form.currentState!.validate())
                                      ref
                                          .read(authControllerProvider.notifier)
                                          .signUpAdmin(
                                              context: context,
                                              firstName: first.text.trim(),
                                              lastName: last.text.trim(),
                                              email: email.text
                                                  .trim()
                                                  .toLowerCase(),
                                              password: password.text,
                                              isAdmin: widget.type == 'admin');
                                  },
                            child: Text(
                                busy ? 'Creating account…' : 'Create account')),
                      ])),
                ))));
  }
}
