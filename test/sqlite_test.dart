// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// VMOptions=--optimization-counter-threshold=5

import "dart:io";

import "package:ffi/ffi.dart";
import "package:test/test.dart";

import 'package:sqlite3/sqlite.dart';

void main() {
  final dbPath = Platform.script.resolve("test_plain.db").path;
  test("sqlite integration test", () {
    Database d = Database(path: dbPath);
    d.execute("drop table if exists Cookies;");
    d.execute("""
      create table Cookies (
        id integer primary key,
        name text not null,
        alternative_name text
      );""");
    d.execute("""
      insert into Cookies (id, name, alternative_name)
      values
        (1,'Chocolade chip cookie', 'Chocolade cookie'),
        (2,'Ginger cookie', null),
        (3,'Cinnamon roll', null)
      ;""");
    var result = d.query("""
      select
        id,
        name,
        alternative_name,
        case
          when id=1 then 'foo'
          when id=2 then 42
          when id=3 then null
        end as multi_typed_column
      from Cookies
      ;""");
    for (var r in result) {
      int id = r['id'];
      expect(true, 1 <= id && id <= 3);
      String name = r['name'];
      expect(true, name is String);
      final alternativeName = r["alternative_name"] as String?;
      dynamic multiTypedValue = r["multi_typed_column"];
      expect(
          true,
          multiTypedValue == 42 ||
              multiTypedValue == 'foo' ||
              multiTypedValue == null);
      print("$id $name $alternativeName $multiTypedValue");
    }
    try {
      result = d.query("""
        select
          id,
          name,
          alternative_name,
          case
            when id=1 then 'foo'
            when id=2 then 42
            when id=3 then null
          end as multi_typed_column
        from Cookies
        ;""");
      for (var r in result) {
        int id = r["id"];
        expect(true, 1 <= id && id <= 3);
        String name = r['name'];
        expect(true, name is String);
        final alternativeName = r["alternative_name"] as String?;
        dynamic multiTypedValue = r["multi_typed_column"];
        expect(
            true,
            multiTypedValue == 42 ||
                multiTypedValue == 'foo' ||
                multiTypedValue == null);
        print("$id $name $alternativeName $multiTypedValue");
      }
    } on SQLiteException catch (e) {
      print("expected exception on accessing result data after close: $e");
    }
    try {
      d.query("""
      select
        id,
        non_existing_column
      from Cookies
      ;""");
    } on SQLiteException catch (e) {
      print("expected this query to fail: $e");
    }
    d.execute("drop table Cookies;");
    d.close();
  });

  test("test exec callback", () {
    Database d = Database(path: dbPath);
    d.execute("""drop table if exists Cookies;
      create table Cookies (
        id integer primary key,
        name text not null,
        alternative_name text
      );
      select * from Cookies;
      """);
  });

  test("concurrent db open and queries", () {
    Database d = Database(path: dbPath);
    Database d2 = Database(path: dbPath);
    d.execute("drop table if exists Cookies;");
    d.execute("""
      create table Cookies (
        id integer primary key,
        name text not null,
        alternative_name text
      );""");
    d.execute("""
      insert into Cookies (id, name, alternative_name)
      values
        (1,'Chocolade chip cookie', 'Chocolade cookie'),
        (2,'Ginger cookie', null),
        (3,'Cinnamon roll', null)
      ;""");
    var r = d.query("select * from Cookies;");
    var r2 = d2.query("select * from Cookies;");
    var r3 = d2.query("select * from Cookies;");
    print('$r $r2 $r3');
    expect(2, r[1]["id"]);
    expect(1, r2[0]["id"]);
    expect(1, r3.first["id"]);
    d.close();
    d2.close();
  });

  test("stress test", () {
    Database d = Database(path: dbPath);
    d.execute("drop table if exists Cookies;");
    d.execute("""
      create table Cookies (
        id integer primary key,
        name text not null,
        alternative_name text
      );""");
    int repeats = 100;
    for (int i = 0; i < repeats; i++) {
      d.execute("""
      insert into Cookies (name, alternative_name)
      values
        ('Chocolade chip cookie', 'Chocolade cookie'),
        ('Ginger cookie', null),
        ('Cinnamon roll', null)
      ;""");
    }
    var r = d.query("select count(*) from Cookies;");
    int count = r.first.entries.first.value;
    expect(count, 3 * repeats);
    d.close();
  });
  test("Utf8 unit test", () {
    final String test = 'Hasta Mañana';
    final medium = test.toNativeUtf8();
    expect(test, medium.toDartString());
    calloc.free(medium);
  });

  test("Test db params", () {
    Database d = Database(path: dbPath);
    d.execute("drop table if exists Cookies;");
    d.execute("""
      create table Cookies (
        id integer primary key,
        name text not null,
        alternative_name text
      );""");
    d.executeWithResult("""
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
    var resultSet = d.query("select * from Cookies where id = ?;", params: [1]);
    print(resultSet);
    expect(resultSet.single['id'], 1);
    d.close();
  });
}
