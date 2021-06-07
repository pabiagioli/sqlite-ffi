// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A synchronous SQLite wrapper.
///
/// Written using dart:ffi.
library sqlite;

export "src/impl/database.dart";
export "src/impl/result.dart";
export "src/impl/batch.dart";
export "src/exception/sqlite_exception.dart";
export 'src/impl/sqlite_options.dart';
export 'src/security/security_options.dart';
export 'src/impl/named_ops.dart';
