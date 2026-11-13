import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DatabaseFactory platformDatabaseFactory() {
  sqfliteFfiInit();
  return databaseFactoryFfi;
}
