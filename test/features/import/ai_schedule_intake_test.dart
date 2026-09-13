// AI 응답 텍스트를 검토 대기로 들이는 경로를 **UI 없이** 검사한다.
//
// 이 함수가 생긴 이유는 단축어(App Intents) 경로가 BuildContext를 가질 수
// 없기 때문이다 — 히어로와 인텐트가 **같은 함수**를 써야 중복 판정 규칙이
// 두 벌로 갈라지지 않는다.

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/import/data/ai_schedule_intake.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
  });

  tearDown(() async {
    await db.close();
  });

  const twoItems = '''
[
  {"title": "운동회", "date": "2026-10-05"},
  {"title": "학예회", "date": "2026-11-20", "description": "강당"}
]
''';

  test('정상 JSON 두 건을 검토 대기로 넣는다', () async {
    final result = await intakeAiScheduleText(repo, twoItems);

    expect(result.created, 2);
    expect(result.dup, 0);
    expect(result.invalid, 0);

    final saved = await repo.getSchedules();
    expect(saved.map((s) => s.title), containsAll(['운동회', '학예회']));
  });

  test('같은 텍스트를 두 번 넣으면 두 번째는 전부 중복이다', () async {
    await intakeAiScheduleText(repo, twoItems);
    final second = await intakeAiScheduleText(repo, twoItems);

    expect(second.created, 0);
    expect(second.dup, 2);
  });

  test('한 텍스트 안의 같은 항목도 중복으로 센다', () async {
    const dupInside = '''
[
  {"title": "운동회", "date": "2026-10-05"},
  {"title": "운동회", "date": "2026-10-05"}
]
''';
    final result = await intakeAiScheduleText(repo, dupInside);

    expect(result.created, 1);
    expect(result.dup, 1);
  });

  test('날짜 형식이 깨진 항목은 invalid로 센다', () async {
    const broken = '''
[
  {"title": "운동회", "date": "2026-10-05"},
  {"title": "형식오류", "date": "언젠가"}
]
''';
    final result = await intakeAiScheduleText(repo, broken);

    expect(result.created, 1);
    expect(result.invalid, 1);
  });

  test('JSON이 아니면 아무것도 넣지 않는다', () async {
    final result = await intakeAiScheduleText(repo, '그냥 텍스트');

    expect(result.created, 0);
    expect(result.dup, 0);
    expect(result.invalid, 0);
    expect(await repo.getSchedules(), isEmpty);
  });

  test('kind를 넘기면 그 종류로 저장한다', () async {
    await intakeAiScheduleText(repo, twoItems, kind: EntryKind.task);

    final saved = await repo.getSchedules();
    expect(saved.every((s) => s.kind == EntryKind.task), isTrue);
  });

  group('상태를 고를 수 있다 — 단축어는 검토를 건너뛴다', () {
    test('기본은 검토 대기다 — 화면 경로(히어로)의 동작을 바꾸지 않는다', () async {
      await intakeAiScheduleText(repo, twoItems);

      final saved = await repo.getSchedules();
      expect(saved.every((s) => s.status == ScheduleStatus.pending), isTrue);
    });

    test('confirmed를 주면 확정으로 저장한다', () async {
      await intakeAiScheduleText(
        repo,
        twoItems,
        status: ScheduleStatus.confirmed,
      );

      final saved = await repo.getSchedules();
      expect(saved, hasLength(2));
      expect(saved.every((s) => s.status == ScheduleStatus.confirmed), isTrue);
    });

    test('넣은 일정의 id를 돌려준다 — 호출부가 캘린더 이벤트를 만들 수 있어야 한다', () async {
      final result = await intakeAiScheduleText(
        repo,
        twoItems,
        status: ScheduleStatus.confirmed,
      );

      expect(result.ids, hasLength(2));
      final saved = await repo.getSchedules();
      expect(result.ids.toSet(), saved.map((s) => s.id).toSet());
    });

    test('중복으로 걸러진 것은 id에 들어가지 않는다', () async {
      await intakeAiScheduleText(repo, twoItems);
      final second = await intakeAiScheduleText(repo, twoItems);

      expect(second.created, 0);
      expect(second.ids, isEmpty, reason: '넣지 않은 것의 id가 새면 없는 이벤트를 만든다');
    });
  });
}
