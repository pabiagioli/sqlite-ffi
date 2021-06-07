


import '../impl/database.dart';

class SecurityOptions {
  final String _password;
  SecurityOptions(this._password);

  void migrateCipher(Database db) {
    db.execute("PRAGMA cipher_migrate;");
  }

  void setPassword(Database db) {
    db.execute("PRAGMA key = $_password;");
  }

  void changePassword(Database db, String password) {
    db.execute("PRAGMA rekey = $password;");
  }
}