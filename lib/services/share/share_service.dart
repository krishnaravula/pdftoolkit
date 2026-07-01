import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  Future<void> shareFile(String path, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: subject),
    );
  }

  Future<OpenResult> openFile(String path) {
    return OpenFilex.open(path);
  }
}
