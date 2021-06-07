import 'dart:developer';
import 'package:logging/logging.dart';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqlite3/src/bindings/sqlite3.ffi.dart';
import 'package:sqlite3/src/bindings/type_utils.dart';
import 'package:sqlite3/src/exception/sqlite_exception.dart';
import 'package:sqlite3/src/impl/result.dart';

class PreparedStatement {
  final Pointer<sqlite3> _database;
  final SQLite3 bindings;
  final String _sql;
  final List<Object?> params;
  final bool debugMode;
  BehaviorSubject<List<Map<String, dynamic>>> _resultsAsync = BehaviorSubject();

  PreparedStatement(this._database, this.bindings, this._sql,
      {this.params = const [], this.debugMode = true});

  List<Map<String, dynamic>> execute(){
    _execute();
    return _resultsAsync.value;
  }

  Stream<List<Map<String, dynamic>>> runAsync(){
    _execute();
    return _resultsAsync.stream;
  }

  void _execute() {
    Map<String,List<Object?>>? remaining = {_sql : params };
    do{
      remaining = _run(
          remaining!.entries.first.key,
          remaining.entries.first.value);
    }while(remaining != null);
    _resultsAsync.sink.close();
  }

  Map<String,List<Object?>>? _run(String remainingSQL, List<Object?> remainingParams) {
    return using((arena){
      Pointer<Pointer<sqlite3_stmt>> statementOut = arena();
      Pointer<Pointer<Int8>> pzTail = arena();
      final queryC = remainingSQL.toInt8(arena: arena);
      int resultCode = bindings.sqlite3_prepare_v2(
          _database, queryC, -1, statementOut, pzTail);
      Pointer<sqlite3_stmt> statement = statementOut.value;

      if (resultCode != SQLITE_OK) {
        bindings.sqlite3_finalize(statement);
        throw _loadError(resultCode);
      }
      int paramCount = bindings.sqlite3_bind_parameter_count(statement);
      final paramsForThisStatement = paramCount > 0 ? remainingParams.take(paramCount)
          .toList() : [];
      // bind parameters in the SQL query
      final allocatedWhileBinding = _bindValues(
          statement, paramsForThisStatement, arena: arena);

      Map<String, int> columnIndices = {};
      int columnCount = bindings.sqlite3_column_count(statement);
      for (int i = 0; i < columnCount; i++) {
        String columnName =
        bindings.sqlite3_column_name(statement, i).toDartString();
        columnIndices[columnName] = i;
      }
      final expandedSQL = bindings.sqlite3_expanded_sql(statement);
      final processedSQL = expandedSQL.isNull() ? '' : expandedSQL.toDartString();
      final chunk = Result(bindings, statement, columnIndices).resultSet();
      // free all the allocated bindings after reading all the data
      allocatedWhileBinding.forEach((ptr) {
        arena.free(ptr);
      });

      if (pzTail.isNull() || pzTail.value.isNull()) {
        remainingSQL = '';
      } else {
        remainingSQL = pzTail.value.toDartString().trim();
        remainingParams = remainingParams.sublist(paramCount);
      }
      if(debugMode) {
        log("processed successfully: $processedSQL", level: Level.ALL.value);
      }
      _resultsAsync.sink.add(chunk);
      if(remainingSQL.isNotEmpty) {
        return {
          remainingSQL:
          remainingParams
        };
      }
      return null;
    });
  }

  List<Pointer> _bindValues(Pointer<sqlite3_stmt> statement, List<Object?> params, {Allocator? arena}) {
    List<Pointer> allocatedWhileBinding = [];
    var param;
    var position = 1;
    for (int i = 0; i < params.length; i++) {
      param = params[i];
      position = i + 1;
      if(param == null) {
        bindings.sqlite3_bind_null(statement, position);
      } else if (param is int) {
        bindings.sqlite3_bind_int64(statement, position, param);
      } else if (param is double) {
        bindings.sqlite3_bind_double(statement, position, param.toDouble());
      } else if (param is String) {
        final ptr = param.toInt8(arena: arena);
        bindings.sqlite3_bind_text(statement, position, ptr, param.length, nullptr);
        allocatedWhileBinding.add(ptr);
      } else if (param is Uint8List) {
        final ptr = param.toNativeBlob(arena: arena).cast<Void>();
        bindings.sqlite3_bind_blob64(statement, position, ptr, param.length, nullptr);
        allocatedWhileBinding.add(ptr);
      }
    }
    return allocatedWhileBinding;
  }

  SQLiteException _loadError(int errorCode) {
    String errorMessage = bindings.sqlite3_errmsg(_database).cast<Utf8>().toDartString();
    String errorCodeExplanation =
    bindings.sqlite3_errstr(errorCode).cast<Utf8>().toDartString();
    return SQLiteException(
        "$errorMessage (Code $errorCode: $errorCodeExplanation)");
  }
}