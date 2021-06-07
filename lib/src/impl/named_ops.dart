import 'dart:io';

class NamedSQLiteOps {
  static final namedQueryLine = RegExp(r'^([0-9A-Za-z_\- ]+):$');

  static Future<Map<String, String>> processFile(File file) async {
    final lines = await file.readAsLines();
    return await processLines(lines);
  }

  static Future<Map<String, String>> processLines(List<String> lines) async {
    Map<String, String> result = {};
    String? key;
    StringBuffer? currentBuf;
    for (int i = 0; i < lines.length; i++) {
      if (namedQueryLine.hasMatch(lines[i].trim())) {
        if (key != null && currentBuf != null) {
          result[key] = currentBuf.toString().trim();
        }
        key = namedQueryLine.firstMatch(lines[i])!.group(1)!.trim();
        print("processing $key");
        currentBuf = StringBuffer();
      } else {
        if (key != null) currentBuf?.writeln(lines[i].trim());
      }
    }
    // add last key and value
    if (key != null && currentBuf != null) {
      result[key] = currentBuf.toString().trim();
    }
    return result;
  }
}
