import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';

void main() {
  group('DatabaseHelper 스키마 상수', () {
    test('테이블명 상수가 정의되어 있음', () {
      expect(DatabaseHelper.tableImportedSchedules, 'imported_schedules');
      expect(DatabaseHelper.tableSchedules, 'schedules');
      expect(DatabaseHelper.tableCalendarEvents, 'calendar_events');
    });

    test('싱글턴 인스턴스가 동일함', () {
      final instance1 = DatabaseHelper.instance;
      final instance2 = DatabaseHelper.instance;
      expect(identical(instance1, instance2), true);
    });
  });
}
