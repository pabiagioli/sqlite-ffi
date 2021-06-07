import 'package:sqlite3/sqlite.dart';
import 'package:test/test.dart';

void main() {
  test('test batch', () {
    final _db = Database(path: ':memory:');
    final batch = _db.batch();
    batch.execute("drop table if exists Cookies;");
    batch.execute("""
      create table Cookies (
        id integer primary key,
        name text not null,
        alternative_name text
      );""");
    batch.execute("""
      insert into Cookies (id, name, alternative_name)
      values
        (?, ?, ?),
        (?, ?, ?),
        (?, ?, ?)
        ;
        -- (1,'Chocolade chip cookie', 'Chocolade cookie'),
        -- (2,'Ginger cookie', null),
        -- (3,'Cinnamon roll', null)
      """, params: [
      1,
      'Chocolade chip cookie',
      'Chocolade cookie',
      2,
      'Ginger cookie',
      null,
      3,
      'Cinnamon roll',
      null
    ]);
    batch.execute("""
    SELECT * 
    FROM Cookies
    WHERE id = ?;""", params: [1]);
    //final Result r = batch.commit();
    final resultSet = batch.commit();
    expect(resultSet.length, 1);
    //r.close();
    _db.close();
  });

  test('test tx', () {
    final _db = Database(path: ':memory:');
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
        -- (1,'Chocolade chip cookie', 'Chocolade cookie'),
        -- (2,'Ginger cookie', null),
        -- (3,'Cinnamon roll', null)
      ;""", params: [
      1,
      'Chocolade chip cookie',
      'Chocolade cookie',
      2,
      'Ginger cookie',
      null,
      3,
      'Cinnamon roll',
      null
    ]);
    final resultSet = tx.commit();
    final resultSet2 = _db.query("""SELECT * 
    FROM Cookies
    WHERE id = ?;""", params: [1]);

    expect(resultSet.isEmpty, isTrue);
    expect(resultSet2.single['id'], 1);
    _db.close();
  });
}