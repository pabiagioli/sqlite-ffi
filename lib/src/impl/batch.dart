import 'database.dart';

class SQLiteBatch {
  StringBuffer _sqlBatch = StringBuffer();
  List<Object?> _sqlParams = [];

  final Database _db;
  SQLiteBatch(this._db);

  void execute(String sql, {List<Object?> params = const []}) {
    _sqlBatch.writeln(sql);
    _sqlParams.addAll(params);
  }

  List<Map<String, dynamic>> commit() {
    return _db.query(_sqlBatch.toString(), params: _sqlParams);
  }

  Stream<List<Map<String, Object?>>> commitAsync() {
    return _db.executeAsync(_sqlBatch.toString(), params: _sqlParams);
  }
}

class SQLiteTransaction extends SQLiteBatch {

  SQLiteTransaction(Database _db, {TxLockMode lock = TxLockMode.DEFERRED}): super(_db){
    this._sqlBatch.writeln('BEGIN ${lock.toString().split('.').last} TRANSACTION;');
  }

  void savePoint(String name) {
    this._sqlBatch.writeln('SAVEPOINT $name;');
  }

  @override
  List<Map<String, dynamic>> commit() {
    this._sqlBatch.writeln('COMMIT TRANSACTION;');
    return super.commit();
  }

  @override
  Stream<List<Map<String, Object?>>> commitAsync() {
    this._sqlBatch.writeln('COMMIT TRANSACTION;');
    return super.commitAsync();
  }
}

enum TxLockMode {
  DEFERRED , IMMEDIATE , EXCLUSIVE
}