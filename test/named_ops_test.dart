import 'package:sqlite3/sqlite.dart';
import 'package:test/test.dart';
import 'package:file/memory.dart' as mem;

void main() {
  test('test named query', () async {
    final file = mem.MemoryFileSystem().file('test.sql')..writeAsStringSync("""
    SELECT * FROM ErrorTable;
        
    select_all:
    SELECT * FROM Cookies;
    
    select_by_id:
    SELECT * 
    FROM Cookies
    WHERE id = ?;
    """);
    final result = await NamedSQLiteOps.processFile(file);
    print(result);
    expect(result.length, 2);
  });
}
