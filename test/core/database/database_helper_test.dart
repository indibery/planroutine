import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  group('마이그레이션 v5 → v6 (is_important)', () {
    late Directory tempDir;
    late String dbPath;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('planroutine_mig_test');
      dbPath = '${tempDir.path}/mig.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('v5 DB의 기존 이벤트가 업그레이드 후 보존되고 is_important 기본 0', () async {
      // v5 스키마(= is_important 없음)로 DB를 만들고 이벤트 1건 삽입
      final v5 = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableCalendarEvents} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                description TEXT,
                event_date TEXT NOT NULL,
                end_date TEXT,
                is_all_day INTEGER NOT NULL DEFAULT 1,
                color TEXT,
                schedule_id INTEGER,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                deleted_at TEXT,
                completed_at TEXT,
                google_event_id TEXT,
                device_event_id TEXT
              )
            ''');
          },
        ),
      );
      await v5.insert(DatabaseHelper.tableCalendarEvents, {
        'title': '기존 이벤트',
        'event_date': '2026-03-02',
        'is_all_day': 1,
        'created_at': '2026-03-01T09:00:00.000',
        'updated_at': '2026-03-01T09:00:00.000',
      });
      await v5.close();

      // DatabaseHelper(v6)로 같은 파일 열기 → _onUpgrade 실행
      final helper = DatabaseHelper.forTesting(path: dbPath);
      final db = await helper.database;

      final rows = await db.query(DatabaseHelper.tableCalendarEvents);
      expect(rows.length, 1, reason: '기존 행 보존');
      expect(rows.first['title'], '기존 이벤트');
      expect(rows.first['is_important'], 0, reason: '신규 컬럼 기본값 0');

      await helper.close();
    });
  });
}
