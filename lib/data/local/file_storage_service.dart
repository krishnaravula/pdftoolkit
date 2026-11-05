import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/config/env.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/memory_utils.dart';

class FileStorageService {
  String? _thumbnailsDir;
  String? _tempDir;

  Future<String> get thumbnailsDirectory async {
    _thumbnailsDir ??= await _subdir(Env.thumbnailsDirName);
    return _thumbnailsDir!;
  }

  Future<String> get tempDirectory async {
    _tempDir ??= await _subdir(Env.tempDirName);
    return _tempDir!;
  }

  Future<String> get openedPdfsDirectory async {
    final cache = await getTemporaryDirectory();
    final path = p.join(cache.path, Env.openedPdfsDirName);
    await FileUtils.ensureDir(path);
    return path;
  }

  Future<String> createTempPath({String extension = '.jpg'}) async {
    final dir = await tempDirectory;
    return p.join(dir, FileUtils.tempFileName(extension: extension));
  }

  Future<void> cleanupStaleTempFiles() async {
    final dir = await tempDirectory;
    await MemoryUtils.cleanupDirectory(dir);
    // Enforce size-based policy (e.g., 500MB)
    await MemoryUtils.cleanupByTotalSize(dir);
    final openedPdfs = await openedPdfsDirectory;
    await MemoryUtils.cleanupDirectory(
      openedPdfs,
      maxAge: const Duration(days: 7),
    );
    await MemoryUtils.cleanupByTotalSize(
      openedPdfs,
      maxSizeBytes: 250 * 1024 * 1024,
    );
  }

  Future<String> _subdir(String name) async {
    final root = await getApplicationDocumentsDirectory();
    final pdfToolsRoot = p.join(root.path, Env.appFolderName);
    final path = p.join(pdfToolsRoot, name);
    await FileUtils.ensureDir(path);
    return path;
  }
}
