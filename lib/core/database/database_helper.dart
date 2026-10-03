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
  static const _databaseVersion = 10;

  // 테이블명
  static const tableImportedSchedules = 'imported_schedules';
  static const tableSchedules = 'schedules';
  static const tableCalendarEvents = 'calendar_events';
  static const tableMemos = 'memos';
  static const tableGuidancePeople = 'guidance_people';
  static const tableGuidanceRecords = 'guidance_records';
  static const tableGuidanceRevisions = 'guidance_revisions';
  static const tableGuidanceAttachments = 'guidance_attachments';

  final String? _customPath;
  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = _customPath ?? join(await getDatabasesPath(), _databaseName);
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
  /// v4 → v5: 기기 캘린더(device_calendar) 중복 방지. calendar_events에
  /// [device_event_id] 컬럼 추가. 동일 패턴.
  /// v5 → v6: 중요 표시. calendar_events에 [is_important] 컬럼 추가.
  /// 0 = 일반, 1 = 중요. 격자/목록에서 ★로 강조.
  /// v6 → v7: 업무/행사 구분. schedules/calendar_events에 [kind] 컬럼 추가.
  /// v7 → v8: 검토 상태. calendar_events에 [reviewed_at] 컬럼 추가.
  /// v8 → v9: 포스트잇. [memos] 테이블 신설(기존 테이블은 그대로).
  /// v9 → v10: 지도 기록. [guidance_*] 테이블 넷 신설(기존 테이블은 그대로).
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
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE $tableCalendarEvents ADD COLUMN device_event_id TEXT',
      );
    }
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE $tableCalendarEvents '
        'ADD COLUMN is_important INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 7) {
      // 업무/행사 구분. 기본값 task라 기존 데이터는 전부 업무가 된다 —
      // 지금까지 들어온 것은 사실상 전부 CSV(생산문서등록대장)이므로 맞는 분류다.
      for (final table in [tableSchedules, tableCalendarEvents]) {
        await db.execute(
          "ALTER TABLE $table ADD COLUMN kind TEXT NOT NULL DEFAULT 'task'",
        );
      }
    }
    if (oldVersion < 8) {
      // 가져온 자료의 검토 상태. 편집 시트에서 저장하면 기록되고, 그때 `작년` 배지와
      // 연도 칩이 함께 꺼진다. 기존 행은 NULL이라 아직 검토하지 않은 것으로 남는다 —
      // 백필하지 않는 것이 곧 맞는 상태다.
      await db.execute(
        'ALTER TABLE $tableCalendarEvents ADD COLUMN reviewed_at TEXT',
      );
    }
    if (oldVersion < 9) {
      // 포스트잇(선택 탭). 기존 테이블은 건드리지 않는다.
      await _createMemos(db);
    }
    if (oldVersion < 10) {
      // 지도 기록(선택 탭). 기존 테이블은 건드리지 않는다.
      await _createGuidance(db);
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
        kind TEXT NOT NULL DEFAULT 'task',
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
        device_event_id TEXT,
        is_important INTEGER NOT NULL DEFAULT 0,
        kind TEXT NOT NULL DEFAULT 'task',
        reviewed_at TEXT,
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

    await _createMemos(db);
    await _createGuidance(db);
  }

  /// `memos` 테이블. `_onCreate`와 v8→v9 업그레이드가 같은 정의를 쓴다.
  static Future<void> _createMemos(Database db) async {
    await db.execute('''
      CREATE TABLE $tableMemos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT 'yellow',
        memo_date TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_memo_date ON $tableMemos(memo_date)');
  }

  /// 지도 기록 테이블 넷. `_onCreate`와 v9→v10 업그레이드가 같은 정의를 쓴다.
  ///
  /// `guidance_revisions`는 **추가만 한다** — UPDATE 없음, DELETE는 영구 삭제 한 곳
  /// (`guidance_append_only_guard_test.dart`가 지킨다).
  static Future<void> _createGuidance(Database db) async {
    await db.execute('''
      CREATE TABLE $tableGuidancePeople (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'student',
        memo TEXT,
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableGuidanceRecords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableGuidanceRevisions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL,
        revision_no INTEGER NOT NULL,
        saved_at TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'guidance',
        status TEXT NOT NULL DEFAULT 'open',
        occurred_precision TEXT NOT NULL DEFAULT 'exact',
        occurred_at TEXT,
        occurred_text TEXT,
        title TEXT NOT NULL,
        place TEXT,
        participants TEXT NOT NULL DEFAULT '[]',
        facts TEXT,
        quotes TEXT,
        actions TEXT,
        UNIQUE (record_id, revision_no),
        FOREIGN KEY (record_id) REFERENCES $tableGuidanceRecords(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableGuidanceAttachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        source TEXT NOT NULL,
        file_name TEXT NOT NULL,
        original_name TEXT,
        sha256 TEXT NOT NULL,
        byte_size INTEGER NOT NULL,
        duration_ms INTEGER,
        captured_at TEXT,
        attached_at TEXT NOT NULL,
        removed_at TEXT,
        FOREIGN KEY (record_id) REFERENCES $tableGuidanceRecords(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_guidance_rev_record ON $tableGuidanceRevisions(record_id)',
    );
    await db.execute(
      'CREATE INDEX idx_guidance_att_record ON $tableGuidanceAttachments(record_id)',
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
      await txn.delete(tableMemos);
      await txn.delete(tableGuidanceAttachments);
      await txn.delete(tableGuidanceRevisions);
      await txn.delete(tableGuidanceRecords);
      await txn.delete(tableGuidancePeople);
      await txn.delete('sqlite_sequence');
    });
  }
}
