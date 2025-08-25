// lib/utils/file_saver_mobile.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'file_saver.dart';

class FileSaverMobile implements FileSaver {
  @override
  Future<void> savePdf(List<int> bytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
  }
}

FileSaver getPlatformFileSaver() => FileSaverMobile();
