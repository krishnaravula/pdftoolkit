import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/services/storage/signature_storage_service.dart';

void main() {
  test('saved signature can be loaded and deleted', () async {
    final directory = Directory.systemTemp.createTempSync('saved_signature');
    addTearDown(() => directory.deleteSync(recursive: true));
    final storage = SignatureStorageService(
      supportDirectory: () async => directory,
    );
    const bytes = [137, 80, 78, 71, 1, 2, 3];

    expect(await storage.loadSignature(), isNull);
    await storage.saveSignature(bytes);
    expect(await storage.loadSignature(), bytes);
    await storage.deleteSignature();
    expect(await storage.loadSignature(), isNull);
  });
}
