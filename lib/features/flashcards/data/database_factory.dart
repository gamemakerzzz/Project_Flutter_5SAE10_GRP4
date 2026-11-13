import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as native;
import 'package:sqflite_common/sqlite_api.dart';

import 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_io.dart'
    if (dart.library.js_interop) 'database_factory_web.dart'
    as platform;

DatabaseFactory flashcardDatabaseFactory() {
  if (kIsWeb) return platform.platformDatabaseFactory();
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return native.databaseFactory;
  }
  return platform.platformDatabaseFactory();
}
