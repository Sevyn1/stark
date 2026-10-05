import 'package:flutter_test/flutter_test.dart';
import 'package:stark/core/providers/firebase_provider.dart';
import 'package:stark/core/providers/storage_repository_provider.dart';

void main() {
  test(
    'Live default disables uploads without creating a Firebase Storage client',
    () async {
      expect(imageUploadsEnabled, false);
      final result = await StorageRepository().storeFile(
        path: 'profiles',
        id: 'u',
        file: null,
        webFile: null,
      );
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message, contains('not enabled')),
        (_) => fail('Disabled upload must not claim success'),
      );
    },
  );
}
