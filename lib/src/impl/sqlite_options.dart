import 'dart:ffi';
import 'dart:io';

class SQLiteOptions {
  final String libraryName;
  final String libraryPath;
  final bool loadFromSystem;
  final bool debugMode;

  SQLiteOptions(
      {this.libraryName = 'sqlite3',
      this.libraryPath = '',
      this.loadFromSystem = true,
      this.debugMode = true});

  DynamicLibrary loadNativeLibrary() =>
      DynamicLibrary.open(_platformPath(libraryName, libraryPath, loadFromSystem));

  String _platformPath(String name, String path, bool useSystemLib) {
    String prefix = useSystemLib ? 'lib' : '';
    if (Platform.isLinux || Platform.isAndroid || Platform.isFuchsia)
      return path + prefix + name + ".so";
    if (Platform.isMacOS) return path + prefix + name + ".dylib";
    if (Platform.isWindows) return path + name + ".dll";
    throw Exception("Platform not implemented");
  }
}