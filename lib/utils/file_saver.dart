// lib/utils/file_saver.dart
import 'file_saver_mobile.dart' if (dart.library.html) 'file_saver_web.dart';

abstract class FileSaver {
  Future<void> savePdf(List<int> bytes, String fileName);
}

// This factory function will return the correct implementation
FileSaver getFileSaver() => getPlatformFileSaver();
