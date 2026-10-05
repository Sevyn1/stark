import 'package:stark/core/providers/firebase_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../onboarding/widgets/account_header.dart';

/// Replaces the prototype's inactive reset button with Firebase's reset flow.
class RecoveryView extends StatefulWidget {
  const RecoveryView({super.key});
  @override
  State<RecoveryView> createState() => _RecoveryViewState();
}

class _RecoveryViewState extends State<RecoveryView> {
  final email = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String message = '';
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await authService
          .sendPasswordResetEmail(email: email.text.trim().toLowerCase());
      if (mounted)
        setState(() {
          message = const bool.fromEnvironment('LOCAL_DEMO')
              ? 'Reset requested. In this local demo, the Firebase emulator prints the reset link; no email is sent.'
              : 'If an account exists, check its inbox for a reset link.';
        });
    } on FirebaseAuthException catch (_) {
      if (mounted)
        setState(() {
          message =
              'Unable to request a reset. Check the address and connection.';
        });
    } finally {
      if (mounted)
        setState(() {
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Password reset')),
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Form(
                    key: form,
                    child: Column(children: [
                      const AccountHeader(subtitle: 'Recover your account'),
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 20),
                      ElevatedButton(
                          onPressed: busy ? null : send,
                          child: Text(
                              busy ? 'Requesting…' : 'Request reset link')),
                      if (message.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Text(message)),
                    ])),
              ))));
}
