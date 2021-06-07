import 'dart:io';

import 'package:sqlite3/sqlite.dart';
import 'package:test/test.dart';

void main() {
  test('test SQLCipher', () async {
    final dbPath = Platform.script.resolve("test.db").path;
    Database? _db;
    try {
      _db = Database(
          path: dbPath,
          options: SQLiteOptions(
              libraryName: 'sqlcipher',
              libraryPath: '/usr/local/lib/',
              loadFromSystem: true,
              debugMode: true));
      await _db.init(
          currentVersion: 1,
          secOpts: SecurityOptions('myPass'),
          onCreate: (db) async {
            final ddl =
                await File("test/scripts/sample_ddl.sql").readAsStringSync();
            await expectLater(db.executeAsync(ddl), emitsThrough(emitsDone));
          });
      await expectLater(
          _db.executeAsync("SELECT * FROM Artist LIMIT 10;"),
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
      await expectLater(
          _db.executeAsync(
              "SELECT count(*) as allTables FROM sqlite_master WHERE type = 'table'"),
          emits([
            {'allTables': 11}
          ]));
    } finally {
      _db?.close();
    }
  });
}
