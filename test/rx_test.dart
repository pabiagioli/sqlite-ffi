import 'dart:developer';
import 'dart:io';

import 'package:sqlite3/sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('rx Tests', (){
    test('test async', () async {
      final _db = Database(path: ':memory:');
      try {
        final tx = _db.transaction();
        tx.execute("drop table if exists Cookies;");
        tx.execute("""
      create table Cookies (
        id integer primary key,
        name text not null,
        alternative_name text
      );""");
        tx.execute("""
      insert into Cookies (id, name, alternative_name)
      values
        (?, ?, ?),
        (?, ?, ?),
        (?, ?, ?)
        ;""", params: [
          1, 'Chocolade chip cookie', 'Chocolade cookie',
          2, 'Ginger cookie', null,
          3, 'Cinnamon roll', null
        ]);

        final transaction = tx.commitAsync();
        await expectLater(transaction, emitsThrough(emitsDone));
        final query = _db.executeAsync("""SELECT * FROM Cookies WHERE id = ?;""", params: [1]);
        await expectLater(query, emits([{'id': 1, 'name': 'Chocolade chip cookie', 'alternative_name': 'Chocolade cookie'}]));
      }finally {
        _db.close();
      }
    });
    //final initScript = Platform.script.resolve("scripts/sample_ddl.sql");
    test('DDL stress test', () async{
      final _db = Database(path: ':memory:');
      Timeline.startSync('DDL load');
      await _db.init(currentVersion: 1, onCreate: (db) async {
        final ddl = await File("test/scripts/sample_ddl.sql").readAsStringSync();
        await expectLater(db.executeAsync(ddl), emitsThrough(emitsDone));
      });
      Timeline.finishSync();
      Timeline.startSync('Select small data');
      await expectLater(_db.executeAsync("SELECT * FROM Artist LIMIT ?;", params: [10]),
          emits([
            {'ArtistId': 1, 'Name': 'AC/DC'},
            {'ArtistId': 2, 'Name': 'Accept'},
            {'ArtistId': 3, 'Name': 'Aerosmith'},
            {'ArtistId': 4, 'Name': 'Alanis Morissette'},
            {'ArtistId': 5, 'Name': 'Alice In Chains'},
            {'ArtistId': 6, 'Name': 'Antônio Carlos Jobim'},
            {'ArtistId': 7, 'Name': 'Apocalyptica'},
            {'ArtistId': 8, 'Name': 'Audioslave'},
            {'ArtistId': 9, 'Name': 'BackBeat'},
            {'ArtistId': 10, 'Name': 'Billy Cobham'}
          ]));
      await expectLater(_db.executeAsync("SELECT count(*) as allTables FROM sqlite_master WHERE type = 'table'"),
          emits([{'allTables': 11}]));
      Timeline.finishSync();
    });
  });
}