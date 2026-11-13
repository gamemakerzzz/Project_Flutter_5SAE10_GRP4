import 'package:sqflite_common/sqlite_api.dart';

DatabaseFactory platformDatabaseFactory() =>
    throw UnsupportedError('SQLite is unavailable on this platform.');
