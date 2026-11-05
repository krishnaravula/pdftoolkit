import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/env.dart';
import '../../core/errors/app_exception.dart';

abstract class ScanService {
  Future<List<String>> capturePages({int? maxPages});
}

class CunningDocumentScanService implements ScanService {
  @override
  Future<List<String>> capturePages({int? maxPages}) async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      throw const ScanException(
        'Camera permission is required to scan documents.',
      );
    }

    final pictures = await CunningDocumentScanner.getPictures(
      noOfPages: maxPages ?? Env.scanMaxPages,
    );

    if (pictures == null || pictures.isEmpty) {
      throw const ScanException('Scan cancelled or no pages captured.');
    }

    return pictures;
  }
}
