import 'package:stark/core/providers/firebase_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerificationView extends StatefulWidget {
  const VerificationView({super.key});
  @override
  State<VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends State<VerificationView> {
  bool busy = false;
  String message =
      'Request a verification link, then open it and check your status.';
  Future<void> act(bool send) async {
    setState(() => busy = true);
    try {
      final user = authService.currentUser;
      if (user == null) throw StateError('Sign in first.');
      if (send) {
        await user.sendEmailVerification();
        if (mounted)
          setState(() => message = const bool.fromEnvironment('LOCAL_DEMO')
              ? 'The local Firebase emulator prints your verification link. No email is sent.'
              : 'Verification requested. Check your inbox for the link.');
      } else {
        await user.reload();
        if (mounted)
          setState(() => message =
              authService.currentUser?.emailVerified == true
                  ? 'Your email is verified.'
                  : 'Verification is still pending. Open the link first.');
      }
    } catch (_) {
      if (mounted)
        setState(
            () => message = 'Unable to check verification. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: busy ? null : () => act(true),
                child: const Text('Request verification link')),
            TextButton(
                onPressed: busy ? null : () => act(false),
                child: const Text('Check verification status')),
          ])));
}
