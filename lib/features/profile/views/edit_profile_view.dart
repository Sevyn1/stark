import 'package:stark/core/providers/firebase_provider.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stark/features/auth/controllers/auth_controller.dart';
import 'package:stark/utils/snack_bar.dart';
import '../comtrollers/profile_controller.dart';

class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});
  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  final form = GlobalKey<FormState>();
  final first = TextEditingController(),
      last = TextEditingController(),
      role = TextEditingController(),
      phone = TextEditingController();
  Uint8List? photo;
  @override
  void initState() {
    super.initState();
    final u = ref.read(userProvider)!;
    first.text = u.firstName;
    last.text = u.lastName;
    role.text = u.role;
    phone.text = u.phone;
  }

  @override
  void dispose() {
    for (final c in [first, last, role, phone]) c.dispose();
    super.dispose();
  }

  Future<void> selectPhoto() async {
    if (!imageUploadsEnabled) return;
    try {
      final selection = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (selection == null) return;
      final image = selection;
      final size = await image.length();
      if (size == null || size > 5 * 1024 * 1024) {
        if (mounted)
          showSnackBar(context, 'Choose an image smaller than 5 MB.');
        return;
      }
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) throw StateError("Image too large");
      if (mounted) setState(() => photo = bytes);
    } catch (_) {
      if (mounted) showSnackBar(context, 'Unable to select that image.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(userProfileControllerProvider),
        user = ref.watch(userProvider)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: form,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundImage: photo != null
                        ? MemoryImage(photo!)
                        : user.profilePic.isNotEmpty
                        ? NetworkImage(user.profilePic) as ImageProvider
                        : null,
                    child: photo == null && user.profilePic.isEmpty
                        ? Text(user.firstName.isEmpty ? '?' : user.firstName[0])
                        : null,
                  ),
                  if (imageUploadsEnabled)
                    TextButton(
                      onPressed: busy ? null : selectPhoto,
                      child: const Text('Choose profile photo'),
                    ),
                  for (final entry in {
                    first: 'First name',
                    last: 'Last name',
                    role: 'Job title',
                    phone: 'Phone',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: TextFormField(
                        controller: entry.key,
                        decoration: InputDecoration(labelText: entry.value),
                        validator: (s) =>
                            [first, last].contains(entry.key) &&
                                (s == null || s.trim().isEmpty)
                            ? 'This name is required'
                            : null,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : () {
                            if (form.currentState!.validate())
                              ref
                                  .read(userProfileControllerProvider.notifier)
                                  .editUserProfile(
                                    context: context,
                                    profileBytes: photo,
                                    firstName: first.text,
                                    lastName: last.text,
                                    role: role.text,
                                    phone: phone.text,
                                  );
                          },
                    child: Text(busy ? 'Saving…' : 'Save profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
