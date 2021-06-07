# SQLite/SQLCipher Dart Library

This is a Dart FFI layer over SQLite's C header library.
The purpose of this library is provide a common framework to work with SQLite DBs using named queries, 
and SQL scripts and be able to use SQLCipher implementation without having to hack a third party library to make it cross platform.

This uses
https://github.com/dart-lang/language/issues/1642#issuecomment-845204655
And uses Prepared Statements
https://sqlite.org/forum/info/2a9775b88a90d2e6

## Prerequirement

For Windows, Linux, and MacOS, you should make sure, sqlite dev lib installed on your system.

Windows user can download dll from https://www.sqlite.org/download.html

If you do not have any sqlite3.dll or so file, you may found error message:

```
Unhandled exception:
Invalid argument(s): Failed to load dynamic library (126)
#0      _open (dart:ffi-patch/ffi_dynamic_library_patch.dart:13:55)
#1      new DynamicLibrary.open (dart:ffi-patch/ffi_dynamic_library_patch.dart:22:12)
```

## Building and Running this Sample

```sh
# Run ffigen to generate SQLite Dart bindings for sqlite3.h file 
$ dart run ffigen
```

Building and running this sample is done through pub.
Running `pub get` and `pub run example/main` should produce the following output.

```sh
$ pub get
Resolving dependencies... (6.8s)
+ analyzer 0.35.4
...
+ yaml 2.1.15
Downloading analyzer 0.35.4...
Downloading kernel 0.3.14...
Downloading front_end 0.1.14...
Changed 47 dependencies!
Precompiling executables... (18.0s)
Precompiled test:test.

```

```
$ pub run example/main
1 Chocolade chip cookie Chocolade cookie foo
2 Ginger cookie null 42
3 Cinnamon roll null null
1 Chocolade chip cookie Chocolade cookie foo
2 Ginger cookie null 42
expected this query to fail: no such column: non_existing_column (Code 1: SQL logic error)
```

## Tutorial

To use this library, simply define the `File` where the SQLite/SQLCipher library file is

```dart
final dbPath = Platform.script.resolve("test.db").path;
SQLiteOptions _options = SQLiteOptions(
    libraryName: 'sqlite3', // file name (without extension and without "lib" prefix)
    libraryPath = '',       //path prefix 
    loadFromSystem = true,  // is it "sqlite3.so" or a system library like "libsqlite3.so"
    this.debugMode = true); // this will print processed queries
Database d = Database(path: dbPath, options: _options);
final List<Map<String,dynamic>> resultSet = d.query("select * from Cookies where id = ?;", params: [1]);
expect(resultSet.single['id'], 1);
```
