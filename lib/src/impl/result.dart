import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:sqlite3/src/bindings/sqlite3.ffi.dart';
import 'package:sqlite3/src/bindings/type_utils.dart';
import 'package:sqlite3/src/collections/closable_iterator.dart';
import 'package:sqlite3/src/exception/sqlite_exception.dart';
import 'package:sqlite3/src/impl/database.dart';

/// [Result] represents a [Database.query]'s result and provides an [Iterable]
/// interface for the results to be consumed.
///
/// Please note that this iterator should be [close]d manually if not all [Row]s
/// are consumed.
class Result extends IterableBase<Row> implements ClosableIterable<Row> {
  final ClosableIterator<Row> _iterator;

  Result(
      SQLite3 bindings,
      Pointer<sqlite3_stmt> statement,
      Map<String, int> columnIndices,
      ) : _iterator = _ResultIterator(bindings, statement, columnIndices) {}

  void close() => _iterator.close();

  ClosableIterator<Row> get iterator => _iterator;

  List<Map<String, dynamic>> resultSet() {
    final List<Map<String, dynamic>> result = [];
    for(var row in this) {
      result.add(row.toMap());
    }
    return result;
    /*return this.fold(
        [], (previousValue, element) => previousValue + [element.toMap()]);*/
  }
}

class _ResultIterator implements ClosableIterator<Row> {
  final SQLite3 _bindings;
  final Pointer<sqlite3_stmt> _statement;
  final Map<String, int> _columnIndices;

  Row? _currentRow;
  bool _closed = false;

  _ResultIterator(this._bindings, this._statement, this._columnIndices) {}

  bool moveNext() {
    if (_closed) {
      throw SQLiteException("The result has already been closed.");
    }
    _currentRow?._setNotCurrent();
    int stepResult = _bindings.sqlite3_step(_statement);
    if (stepResult == SQLITE_ROW) {
      _currentRow = Row._(_bindings, _statement, _columnIndices);
      return true;
    } else {
      close();
      return false;
    }
  }

  Row get current {
    if (_closed) {
      throw SQLiteException("The result has already been closed.");
    }
    return _currentRow!;
  }

  void close() {
    if(_closed) return;
    _currentRow?._setNotCurrent();
    _closed = true;
    _bindings.sqlite3_finalize(_statement);
  }
}

class Row {
  final SQLite3 bindings;
  final Pointer<sqlite3_stmt> _statement;
  final Map<String, int> _columnIndices;

  bool _isCurrentRow = true;

  Row._(this.bindings, this._statement, this._columnIndices) {}

  /// Reads column [columnName].
  ///
  /// By default it returns a dynamically typed value. If [convert] is set to
  /// [Convert.StaticType] the value is converted to the static type computed
  /// for the column by the query compiler.
  dynamic readColumn(String columnName,
      {Convert convert = Convert.DynamicType}) {
    return readColumnByIndex(_columnIndices[columnName]!, convert: convert);
  }

  /// Reads column [columnName].
  ///
  /// By default it returns a dynamically typed value. If [convert] is set to
  /// [Convert.StaticType] the value is converted to the static type computed
  /// for the column by the query compiler.
  dynamic readColumnByIndex(int columnIndex,
      {Convert convert = Convert.DynamicType}) {
    _checkIsCurrentRow();

    Type dynamicType;
    if (convert == Convert.DynamicType) {
      dynamicType =
          _typeFromCode(bindings.sqlite3_column_type(_statement, columnIndex));
    } else {
      dynamicType = _typeFromText(bindings
          .sqlite3_column_decltype(_statement, columnIndex)
          .toDartString());
    }

    switch (dynamicType) {
      case Type.Integer:
        return readColumnByIndexAsInt(columnIndex);
      case Type.Float:
        return readColumnByIndexAsDouble(columnIndex);
      case Type.Text:
        return readColumnByIndexAsText(columnIndex);
      case Type.Blob:
        return readColumnByIndexAsBlob(columnIndex);
      case Type.Null:
      default:
        return null;
    }
  }

  /// Reads column [columnName] and converts to [Type.Integer] if not an
  /// integer.
  int readColumnAsInt(String columnName) {
    return readColumnByIndexAsInt(_columnIndices[columnName]!);
  }

  /// Reads column [columnIndex] and converts to [Type.Integer] if not an
  /// integer.
  int readColumnByIndexAsInt(int columnIndex) {
    _checkIsCurrentRow();
    return bindings.sqlite3_column_int(_statement, columnIndex);
  }

  /// Reads column [columnName] and converts to [Type.Text] if not text.
  String readColumnAsText(String columnName) {
    return readColumnByIndexAsText(_columnIndices[columnName]!);
  }

  /// Reads column [columnIndex] and converts to [Type.Text] if not text.
  String readColumnByIndexAsText(int columnIndex) {
    _checkIsCurrentRow();
    return bindings.sqlite3_column_text(_statement, columnIndex).toDartString();
  }

  double readColumnAsDouble(String columnName) {
    return readColumnByIndexAsDouble(_columnIndices[columnName]!);
  }

  double readColumnByIndexAsDouble(int columnIndex) {
    _checkIsCurrentRow();
    return bindings.sqlite3_column_double(_statement, columnIndex);
  }

  Uint8List readColumnAsBlob(String columnName) {
    return readColumnByIndexAsBlob(_columnIndices[columnName]!);
  }

  Uint8List readColumnByIndexAsBlob(int columnIndex) {
    final length = bindings.sqlite3_column_bytes(_statement, columnIndex);
    if (length == 0) {
      // sqlite3_column_blob returns a null pointer for non-null blobs with
      // a length of 0. Note that we can distinguish this from a proper null
      // by checking the type (which isn't SQLITE_NULL)
      return Uint8List(0);
    }
    return bindings
        .sqlite3_column_blob(_statement, columnIndex)
        .copyRange(length);
  }

  void _checkIsCurrentRow() {
    if (!_isCurrentRow) {
      throw Exception(
          "This row is not the current row, reading data from the non-current"
              " row is not supported by sqlite.");
    }
  }

  void _setNotCurrent() {
    _isCurrentRow = false;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> result = {};
    _columnIndices.forEach((key, value) {
      result[key] = readColumn(key);
    });
    return result;
  }
}

Type _typeFromCode(int code) {
  switch (code) {
    case SQLITE_INTEGER:
      return Type.Integer;
    case SQLITE_FLOAT:
      return Type.Float;
    case SQLITE_TEXT:
      return Type.Text;
    case SQLITE_BLOB:
      return Type.Blob;
    case SQLITE_NULL:
      return Type.Null;
  }
  throw Exception("Unknown type [$code]");
}

Type _typeFromText(String textRepresentation) {
  switch (textRepresentation) {
    case "integer":
      return Type.Integer;
    case "float":
      return Type.Float;
    case "text":
      return Type.Text;
    case "blob":
      return Type.Blob;
    case "null":
      return Type.Null;
  }
  throw Exception("Unknown type [$textRepresentation]");
}

enum Type { Integer, Float, Text, Blob, Null }

enum Convert { DynamicType, StaticType }