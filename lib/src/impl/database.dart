import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:sqlite3/src/bindings/sqlite3.ffi.dart';

import 'sqlite_options.dart';
import 'batch.dart';
import 'statement.dart';
import '../bindings/type_utils.dart';
import '../exception/sqlite_exception.dart';
import '../security/security_options.dart';

/// [Database] represents an open connection to a SQLite database.
///
/// All functions against a database may throw [SQLiteError].
///
/// This database interacts with SQLite synchonously.
class Database {
  late SQLite3 bindings;
  late Pointer<sqlite3> _database;
  late SQLiteOptions _options;

  Pointer<sqlite3> get dbPtr => _database;

  bool _open = false;

  Database(
      {required String path,
      int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_SHAREDCACHE,
      SQLiteOptions? options}) {
    _options = options ?? SQLiteOptions();
    bindings = SQLite3(_options.loadNativeLibrary());
    _openDB(path, flags);
  }

  void _openDB(String path, int flags) {
    Pointer<Pointer<sqlite3>> dbOut = calloc();
    final Pointer<Int8> pathC = path.toInt8();
    final int resultCode =
    bindings.sqlite3_open_v2(pathC, dbOut, flags, nullptr);
    _database = dbOut.value;
    calloc.free(dbOut);
    calloc.free(pathC);

    if (resultCode == SQLITE_OK) {
      _open = true;
    } else {
      // Even if "open" fails, sqlite3 will still create a database object.
      // We can just destroy it.
      SQLiteException exception = _loadError(resultCode);
      close();
      throw exception;
    }
  }

  Future<void> init(
      {required int currentVersion,
      SecurityOptions? secOpts,
      Future<void> Function(Database db)? onConfigure,
      Function(Database db)? onCreate,
      Function(Database db, int oldVersion, int newVersion)? onUpgrade,
      Function(Database db, int oldVersion, int newVersion)?
          onDowngrade}) async {
    if(secOpts != null){
      secOpts.setPassword(this);
      secOpts.migrateCipher(this);
    }
    int oldVersion = getVersion();
    if (onConfigure != null) await onConfigure(this);
    if (oldVersion == 0) {
      await onCreate!(this);
    } else if (oldVersion != currentVersion) {
      if (oldVersion < currentVersion) {
        await onUpgrade!(this, oldVersion, currentVersion);
      } else {
        await onDowngrade!(this, oldVersion, currentVersion);
      }
    }
    setVersion(currentVersion);
  }

  int getVersion() =>
      executeWithResult("PRAGMA user_version;").first.values.first;
  void setVersion(int version) {
    executeWithResult("PRAGMA user_version = $version;");
  }

  SQLiteException _loadError(int errorCode) {
    String errorMessage = bindings.sqlite3_errmsg(_database).cast<Utf8>().toDartString();
    String errorCodeExplanation =
    bindings.sqlite3_errstr(errorCode).cast<Utf8>().toDartString();
    return SQLiteException(
        "$errorMessage (Code $errorCode: $errorCodeExplanation)");
  }

  void execute(String sql, {List<Object?> params = const []}){
    final statement = PreparedStatement(_database, bindings, sql,
        params: params, debugMode: _options.debugMode);
    statement.execute();
  }
  List<Map<String, dynamic>> query(String query, {List<Object?> params = const [] }) =>
      executeWithResult(query, params: params);
  List<Map<String, dynamic>> executeWithResult(String sql, {List<Object?> params = const []}) {
    final statement = PreparedStatement(_database, bindings, sql, params: params, debugMode: _options.debugMode);
    return statement.execute();
  }

  Stream<List<Map<String, Object?>>> executeAsync(String sql, {List<Object?> params = const []}) =>
      PreparedStatement(_database, bindings, sql, params: params, debugMode: _options.debugMode)
          .runAsync();


  /// Close the database.
  ///
  /// This should only be called once on a database unless an exception is
  /// thrown. It should be called at least once to finalize the database and
  /// avoid resource leaks.
  void close() {
    assert(_open);
    final int resultCode = bindings.sqlite3_close_v2(_database);
    if (resultCode == SQLITE_OK) {
      _open = false;
    } else {
      throw _loadError(resultCode);
    }
  }

  SQLiteBatch batch() => SQLiteBatch(this);
  SQLiteTransaction transaction({TxLockMode lock = TxLockMode.DEFERRED}) => SQLiteTransaction(this, lock: lock);
}