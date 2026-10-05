import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:stark/core/failure.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/core/type_defs.dart';

final storageRepositoryProvider = Provider(
  (ref) => StorageRepository(
    firebaseStorage: imageUploadsEnabled ? ref.watch(storageProvider) : null,
    uploadsEnabled: imageUploadsEnabled,
  ),
);

class StorageRepository {
  final FirebaseStorage? _firebaseStorage;
  final bool uploadsEnabled;
  StorageRepository({
    FirebaseStorage? firebaseStorage,
    this.uploadsEnabled = false,
  }) : _firebaseStorage = firebaseStorage;

  FutureEither<String> storeFile({
    required String path,
    required String id,
    required File? file,
    required Uint8List? webFile,
  }) async {
    if (!uploadsEnabled)
      return left(Failure('Image uploads are not enabled for this workspace.'));
    try {
      final ref = _firebaseStorage!.ref().child(path).child(id);
      UploadTask uploadTask;

      if (webFile != null) {
        uploadTask = ref.putData(webFile);
      } else {
        uploadTask = ref.putFile(file!);
      }

      final snapshot = await uploadTask;

      return right(await snapshot.ref.getDownloadURL());
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }
}
