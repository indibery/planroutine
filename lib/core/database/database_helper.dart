import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite 데이터베이스 관리
class DatabaseHelper {
  DatabaseHelper._() : _customPath = null;

  /// 테스트 전용 — 커스텀 경로(보통 `inMemoryDatabasePath`) + FFI 팩토리와
  /// 조합해 파일 I/O 없이 in-memory DB로 repository 유닛 테스트.
  @visibleForTesting
  DatabaseHelper.forTesting({required String path}) : _customPath = path;

  static final instance = DatabaseHelper._();

  static const _databaseName = 'planroutine.db';
  static const _databaseVersion = 4;

  // 테이블명
  static const tableImportedSchedules = 'imported_schedules';
  static const tableSchedules = 'schedules';
  static const tableCalendarEvents = 'calendar_events';

  final String? _customPath;
  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = _customPath ??
        join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 스키마 마이그레이션.
  ///
  /// v1 → v2: 휴지통(soft-delete) 도입. schedules/calendar_events에
  /// [deleted_at] 컬럼 추가. NULL = 활성, ISO8601 문자열 = 삭제 시각.
  /// v2 → v3: 캘린더 이벤트 완료 표시. calendar_events에 [completed_at]
  /// 컬럼 추가. NULL = 미완료, ISO8601 문자열 = 완료 시각.
  /// v3 → v4: 구글 캘린더 중복 방지. calendar_events에 [google_event_id]
  /// 컬럼 추가. NULL = 미저장, 값 있으면 재저장 시 update로 처리.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tableSchedules ADD COLUMN deleted_at TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableCalendarEvents ADD COLUMN deleted_at TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE $tableCalendarEvents ADD COLUMN completed_at TEXT',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE $tableCalendarEvents ADD COLUMN google_event_id TEXT',
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // CSV에서 가져온 작년 일정 (원본 보관)
    await db.execute('''
      CREATE TABLE $tableImportedSchedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_number TEXT,
        approval_type TEXT,
        title TEXT NOT NULL,
        drafter TEXT,
        registration_date TEXT NOT NULL,
        category TEXT,
        sub_category TEXT,
        retention_period TEXT,
        source_year INTEGER,
        imported_at TEXT NOT NULL
      )
    ''');

    // 올해 확정 일정
    await db.execute('''
      CREATE TABLE $tableSchedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        scheduled_date TEXT NOT NULL,
        category TEXT,
        sub_category TEXT,
        source_id INTEGER,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (source_id) REFERENCES $tableImportedSchedules(id)
      )
    ''');

    // 캘린더 이벤트
    await db.execute('''
      CREATE TABLE $tableCalendarEvents (
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
        FOREIGN KEY (schedule_id) REFERENCES $tableSchedules(id)
      )
    ''');

    // 인덱스
    await db.execute(
      'CREATE INDEX idx_imported_date ON $tableImportedSchedules(registration_date)',
    );
    await db.execute(
      'CREATE INDEX idx_imported_category ON $tableImportedSchedules(category)',
    );
    await db.execute(
      'CREATE INDEX idx_schedule_date ON $tableSchedules(scheduled_date)',
    );
    await db.execute(
      'CREATE INDEX idx_schedule_status ON $tableSchedules(status)',
    );
    await db.execute(
      'CREATE INDEX idx_event_date ON $tableCalendarEvents(event_date)',
    );
  }

  /// 데이터베이스 닫기
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// 모든 테이블의 데이터를 삭제한다 (테스트용 전체 초기화).
  ///
  /// - 트랜잭션으로 감싸 중간 실패 시 전체 롤백
  /// - FK 참조 역순(자식 → 부모)으로 삭제하여 제약 위반 방지
  /// - `sqlite_sequence`까지 비워 AUTOINCREMENT id를 1부터 재시작
  Future<void> resetAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableCalendarEvents);
      await txn.delete(tableSchedules);
      await txn.delete(tableImportedSchedules);
      await txn.delete('sqlite_sequence');
    });
  }
}
