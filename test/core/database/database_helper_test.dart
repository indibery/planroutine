import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

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
            // 실제 v5 DB에는 두 테이블이 다 있다. 하나만 만들면 이후 버전의
            // ALTER TABLE이 "no such table"로 터진다.
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableSchedules} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                scheduled_date TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                deleted_at TEXT
              )
            ''');
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

  group('마이그레이션 v6 → v7 (kind)', () {
    late DatabaseHelper db;

    setUpAll(setUpFfiForTests);
    setUp(() => db = freshDatabaseHelper());
    tearDown(() async => db.close());

    Future<List<String>> columnsOf(String table) async {
      final d = await db.database;
      final rows = await d.rawQuery('PRAGMA table_info($table)');
      return rows.map((r) => r['name'] as String).toList();
    }

    test('두 테이블 모두 kind 컬럼을 갖는다', () async {
      expect(await columnsOf(DatabaseHelper.tableSchedules), contains('kind'));
      expect(
        await columnsOf(DatabaseHelper.tableCalendarEvents),
        contains('kind'),
      );
    });

    test('kind를 지정하지 않고 넣으면 업무(task)가 된다', () async {
      final d = await db.database;
      final now = DateTime.now().toIso8601String();
      await d.insert(DatabaseHelper.tableSchedules, {
        'title': '학급편성 결과 제출',
        'scheduled_date': '2026-03-02',
        'status': 'pending',
        'created_at': now,
        'updated_at': now,
      });
      await d.insert(DatabaseHelper.tableCalendarEvents, {
        'title': '학급편성 결과 제출',
        'event_date': '2026-03-02',
        'created_at': now,
        'updated_at': now,
      });

      final s = await d.query(DatabaseHelper.tableSchedules);
      final e = await d.query(DatabaseHelper.tableCalendarEvents);
      expect(s.single['kind'], EntryKind.task.dbValue);
      expect(e.single['kind'], EntryKind.task.dbValue);
    });

    test('학교일정으로 지정해 넣으면 그대로 저장된다', () async {
      final d = await db.database;
      final now = DateTime.now().toIso8601String();
      await d.insert(DatabaseHelper.tableCalendarEvents, {
        'title': '과학의 달 행사',
        'event_date': '2026-04-10',
        'kind': EntryKind.event.dbValue,
        'created_at': now,
        'updated_at': now,
      });

      final e = await d.query(DatabaseHelper.tableCalendarEvents);
      expect(EntryKind.fromValue(e.single['kind'] as String?), EntryKind.event);
    });

    test('v6 DB의 기존 행은 업그레이드 후 업무가 된다', () async {
      // :memory:는 연결을 닫으면 사라지므로 파일 DB가 필요하다.
      final dir = await Directory.systemTemp.createTemp('planroutine_v6');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/v6.db';

      final v6 = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (d, _) async {
            // v7이 손대는 두 테이블만 최소 컬럼으로 재현한다.
            await d.execute('''
              CREATE TABLE ${DatabaseHelper.tableSchedules} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                scheduled_date TEXT NOT NULL
              )
            ''');
            await d.execute('''
              CREATE TABLE ${DatabaseHelper.tableCalendarEvents} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                event_date TEXT NOT NULL
              )
            ''');
            await d.insert(DatabaseHelper.tableCalendarEvents, {
              'title': '작년부터 있던 업무',
              'event_date': '2026-03-02',
            });
          },
        ),
      );
      await v6.close();

      final helper = DatabaseHelper.forTesting(path: path);
      addTearDown(helper.close);
      final d = await helper.database;

      final rows = await d.query(DatabaseHelper.tableCalendarEvents);
      expect(rows.single['title'], '작년부터 있던 업무');
      expect(
        EntryKind.fromValue(rows.single['kind'] as String?),
        EntryKind.task,
        reason: '기존 데이터는 전부 업무로 분류된다',
      );
    });
  });
}
