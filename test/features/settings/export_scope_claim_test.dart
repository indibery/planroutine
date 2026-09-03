// 내보내기의 **범위 주장**은 실제 쿼리와 일치해야 한다.
//
// 쿼리는 `deleted_at IS NULL AND status='confirmed'` — **연도 필터가 없다.**
// 그런데 설정 문구는 `올해 등록된 일정을 CSV 파일로 저장·공유합니다`였다
// (2026-09-03 발견). 지금은 확정 행이 대체로 1년치라 우연히 맞지만,
// **확정 행은 자동 정리 대상이 아니다** — `purgeOlderThan`은
// `deleted_at IS NOT NULL`만 지우므로 확정분은 해마다 쌓인다. 2년 뒤에는 2배가
// "올해"라는 이름으로 나간다.
//
// 이 리포는 같은 계열을 이미 한 번 밟았다: `deleteAllPending`이 카테고리를 무시하는데
// pill은 좁힌 건수를 말해, `행사 4건 삭제`를 눌러 대기 21건이 전부 휴지통으로 갔고
// 스낵바는 `4건을 옮겼어요`라 사라진 사실조차 알리지 않았다.
// **범위를 말하는 문구와 범위를 정하는 쿼리는 양방향으로 묶는다.**

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/settings/data/schedule_csv_exporter.dart';

import '../../helpers/test_database.dart';

/// 연도 범위를 주장하는 낱말. 4자리 연도(`2026`)도 주장으로 본다.
final _yearClaim = RegExp(r'올해|금년|이번\s*해|당해|20\d\d년?');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;
  late Directory tempDir;

  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
    tempDir = await Directory.systemTemp.createTemp('export_scope_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (call) async {
          if (call.method == 'getTemporaryDirectory') return tempDir.path;
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seed(String title, String date, ScheduleStatus status) async {
    await repo.insertConfirmedOrPending(
      Schedule(title: title, scheduledDate: date, status: status),
    );
  }

  test('확정 일정은 연도와 무관하게 전부 내보내진다', () async {
    await seed('재작년 학급편성', '2024-03-02', ScheduleStatus.confirmed);
    await seed('작년 교육과정 운영', '2025-03-02', ScheduleStatus.confirmed);
    await seed('올해 교직원 회의', '2026-03-02', ScheduleStatus.confirmed);
    await seed('아직 검토 안 한 것', '2026-04-01', ScheduleStatus.pending);

    final result = await ScheduleCsvExporter(
      dbHelper: db,
    ).exportActiveSchedules();
    final body = File(result.filePath).readAsStringSync();

    expect(result.count, 3, reason: '확정 3건 전부 — 올해로 좁히지 않는다');
    for (final title in ['재작년 학급편성', '작년 교육과정 운영', '올해 교직원 회의']) {
      expect(body, contains(title), reason: '$title 이 빠졌다');
    }
    expect(body, isNot(contains('아직 검토 안 한 것')), reason: '검토 대기는 내보내지 않는다');
  });

  test('설정 문구가 연도 범위를 주장하지 않는다', () async {
    // `exportDescription`만 본다 — `export_list_tile.dart`가 렌더하는 것은
    // `exportTitle`과 이 문구 둘이고, `exportSection`은 섹션 헤더를 없앤 뒤
    // 프로덕션에서 렌더되지 않는다(`test/tools/visual_check.dart`의 프리뷰 라벨로만
    // 남아 있다). 안 보이는 문자열을 함께 검사하면 루프의 절반이 아무것도 안 지킨다.
    const label = SettingsStrings.exportDescription;
    expect(
      _yearClaim.hasMatch(label),
      isFalse,
      reason:
          '"$label" — 쿼리는 확정분 전체를 내보내는데 문구가 연도를 주장한다. '
          '확정 행은 자동 정리되지 않아 해마다 쌓이므로 이 주장은 매년 더 틀려진다',
    );
  });

  test('휴지통에 든 확정분은 내보내지 않는다', () async {
    // 쿼리의 나머지 절(`deleted_at IS NULL`). 위 테스트가 `status` 절을 잡으니
    // 이걸로 범위 두 조건이 모두 행동으로 고정된다.
    //
    // 반대 방향(쿼리만 연도로 좁히고 문구를 안 고치는 것)을 소스 정규식으로
    // 검사하던 테스트는 지웠다 — 오늘 조건상 **무조건 조기 반환**이라 실패할 수
    // 없었고, 관용구 다섯 개만 알아 `BETWEEN`·바인딩 인자·Dart 후처리로 좁히면
    // 그냥 통과했다. 위 3년치 행동 테스트가 어떤 방식의 좁힘이든 잡는다.
    await seed('남길 확정', '2026-03-02', ScheduleStatus.confirmed);
    await seed('버릴 확정', '2026-03-03', ScheduleStatus.confirmed);
    final all = await repo.getSchedules(status: ScheduleStatus.confirmed);
    await repo.deleteSchedule(
      all.firstWhere((s) => s.title == '버릴 확정').id!,
    );

    final result = await ScheduleCsvExporter(
      dbHelper: db,
    ).exportActiveSchedules();
    final body = File(result.filePath).readAsStringSync();

    expect(result.count, 1);
    expect(body, contains('남길 확정'));
    expect(
      body,
      isNot(contains('버릴 확정')),
      reason: '휴지통 항목이 나가면 사용자가 지운 것이 되살아난다',
    );
  });
}
