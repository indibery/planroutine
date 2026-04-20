import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planroutine/core/database/database_helper.dart';

/// 테스트용 in-memory DatabaseHelper 팩토리.
///
/// FFI 전역 팩토리를 1회 초기화한 뒤, 각 테스트에서 [freshDatabaseHelper]로
/// 새 `DatabaseHelper` 인스턴스를 받아 격리된 in-memory DB 확보.
void setUpFfiForTests() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// 테스트마다 독립된 DB를 갖는 DatabaseHelper 인스턴스 반환.
DatabaseHelper freshDatabaseHelper() {
  return DatabaseHelper.forTesting(path: inMemoryDatabasePath);
}
