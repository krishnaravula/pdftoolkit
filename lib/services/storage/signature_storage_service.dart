import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores an optional reusable signature in app-private storage.
class SignatureStorageService {
  SignatureStorageService({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectory;
  static const _signatureName = 'saved_signature.png';

  Future<Uint8List?> loadSignature() async {
    final file = File(await _signaturePath());
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> saveSignature(List<int> pngBytes) async {
    final path = await _signaturePath();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(pngBytes, flush: true);
  }

  Future<void> deleteSignature() async {
    final file = File(await _signaturePath());
    if (await file.exists()) await file.delete();
  }

  Future<String> _signaturePath() async {
    final root = await _supportDirectory();
    return p.join(root.path, 'PDF Tools', 'signatures', _signatureName);
  }
}
