// lib/utils/file_saver_web.dart

import 'dart:js' as js;
import 'file_saver.dart';

class FileSaverWeb implements FileSaver {
  @override
  Future<void> savePdf(List<int> bytes, String fileName) async {
    // Call the JavaScript function directly
    js.context.callMethod('downloadFile', [bytes, fileName]);
  }
}

FileSaver getPlatformFileSaver() => FileSaverWeb();
