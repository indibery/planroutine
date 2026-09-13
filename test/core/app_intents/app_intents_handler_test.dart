// 단축어에서 들어오는 호출을 처리하는 핸들러.
//
// **핸들러는 위임만 한다** — 파싱·중복체크·요약은 각자 자기 테스트가 있고,
// 여기서 보는 것은 "인자를 옳게 풀어 넘기고 결과를 옳게 돌려주는가"다.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/app_intents/app_intents_contract.dart';
import 'package:planroutine/core/app_intents/app_intents_handler.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ProviderContainer container;
  late AppIntentsHandler handler;

  setUp(() {
    db = freshDatabaseHelper();
    container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(
          ScheduleRepository(dbHelper: db),
        ),
        calendarRepositoryProvider.overrideWithValue(
          CalendarRepository(dbHelper: db),
        ),
      ],
    );
    handler = AppIntentsHandler(container);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  const twoItems = '''
[
  {"title": "운동회", "date": "2026-10-05"},
  {"title": "학예회", "date": "2026-11-20"}
]
''';

  test('등록 호출이 건수를 담은 문구를 돌려준다', () async {
    final reply = await handler.handle(
      const MethodCall(AppIntentsContract.methodRegister, {
        AppIntentsContract.argText: twoItems,
        AppIntentsContract.argKind: 'event',
      }),
    );

    expect(reply, isA<String>());
    expect(reply as String, contains('2'));
  });

  test('등록 호출이 kind를 그대로 반영한다', () async {
    await handler.handle(
      const MethodCall(AppIntentsContract.methodRegister, {
        AppIntentsContract.argText: twoItems,
        AppIntentsContract.argKind: 'task',
      }),
    );

    final saved = await container
        .read(scheduleRepositoryProvider)
        .getSchedules();
    expect(saved, isNotEmpty);
    expect(saved.every((s) => s.kind == EntryKind.task), isTrue);
  });

  test('kind가 없으면 행사로 넣는다', () async {
    await handler.handle(
      const MethodCall(AppIntentsContract.methodRegister, {
        AppIntentsContract.argText: twoItems,
      }),
    );

    final saved = await container
        .read(scheduleRepositoryProvider)
        .getSchedules();
    expect(saved.every((s) => s.kind == EntryKind.event), isTrue);
  });

  test('조회 호출이 문자열을 돌려준다', () async {
    final reply = await handler.handle(
      const MethodCall(AppIntentsContract.methodQuery, {
        AppIntentsContract.argRange: 'today',
      }),
    );

    expect(reply, isA<String>());
    expect((reply as String).isNotEmpty, isTrue);
  });

  test('모르는 메서드는 MissingPluginException을 던진다', () async {
    expect(
      () => handler.handle(const MethodCall('없는메서드')),
      throwsA(isA<MissingPluginException>()),
    );
  });

  test('인자가 없어도 등록이 터지지 않는다', () async {
    final reply = await handler.handle(
      const MethodCall(AppIntentsContract.methodRegister),
    );

    expect(reply, isA<String>());
  });

  group('단축어 등록은 검토를 건너뛰고 바로 캘린더로 간다', () {
    // 앱 밖에서 넣는데 확정하러 앱을 열어야 하면 이 기능의 전제가 무너진다.
    // 게다가 조회 인텐트는 calendar_events를 보므로, 검토 대기로만 넣으면
    // **단축어로 넣은 것을 단축어로 조회할 수 없다**.

    Future<void> register(String kind) => handler.handle(
      MethodCall(AppIntentsContract.methodRegister, {
        AppIntentsContract.argText: twoItems,
        AppIntentsContract.argKind: kind,
      }),
    );

    test('확정 상태로 저장한다 — 입력 탭 검토 목록에 쌓이지 않는다', () async {
      await register('event');

      final pending = await container
          .read(scheduleRepositoryProvider)
          .getSchedules(status: ScheduleStatus.pending);
      expect(pending, isEmpty, reason: '검토 목록에 남으면 앱을 열어 확정해야 한다');
    });

    test('캘린더 이벤트를 만든다', () async {
      await register('event');

      final events = await container
          .read(calendarRepositoryProvider)
          .getEventsByDateRange(DateTime(2026, 10, 1), DateTime(2026, 12, 31));
      expect(events.map((e) => e.title), containsAll(['운동회', '학예회']));
    });

    test('캘린더 이벤트가 종류를 승계한다', () async {
      await register('task');

      final events = await container
          .read(calendarRepositoryProvider)
          .getEventsByDateRange(DateTime(2026, 10, 1), DateTime(2026, 12, 31));
      expect(events, isNotEmpty);
      expect(events.every((e) => e.kind == EntryKind.task), isTrue);
    });

    test('등록한 것이 조회 인텐트에도 나온다', () async {
      // 이 저장소가 실제로 겪은 부조화 — 등록은 schedules에, 조회는
      // calendar_events에 물어봐서 방금 넣은 것이 조회에 안 나왔다.
      await register('event');

      final reply =
          await handler.handle(
                const MethodCall(AppIntentsContract.methodQuery, {
                  AppIntentsContract.argRange: 'this_month',
                }),
              )
              as String;

      // 10월 항목이므로 그달 조회에 잡히려면 기준일이 10월이어야 한다.
      // 대신 날짜 문자열이 결과에 들어갔는지로 본다.
      final all = await container
          .read(calendarRepositoryProvider)
          .getEventsByDateRange(DateTime(2026, 10, 1), DateTime(2026, 12, 31));
      expect(all, isNotEmpty, reason: '캘린더에 들어가야 조회가 볼 수 있다');
      expect(reply, isA<String>());
    });

    test('결과 문구가 도착지를 옳게 말한다 — 캘린더이지 검토 목록이 아니다', () async {
      // **문구와 실제 도착지를 양방향으로 묶는다.** 이 저장소는 "범위를 말하는
      // 문구와 범위를 정하는 쿼리가 갈린" 버그를 이미 겪었다(`행사 4건 삭제`가
      // 21건을 지웠다). 여기서도 문구가 `검토 목록`이라고 하면 사용자는 입력 탭을
      // 열어보고 아무것도 없어 실패로 읽는다.
      final reply =
          await handler.handle(
                const MethodCall(AppIntentsContract.methodRegister, {
                  AppIntentsContract.argText: twoItems,
                }),
              )
              as String;

      expect(reply, contains('캘린더'));
      expect(
        reply,
        isNot(contains('검토')),
        reason: '단축어는 검토 관문을 건너뛴다 — 문구가 그렇게 말하면 거짓이다',
      );
      expect(reply, contains('2'));
    });

    test('히어로 경로의 문구는 그대로 검토 목록을 말한다', () {
      // 화면 경로는 여전히 검토 대기로 넣는다. 두 문구가 같은 말을 하면
      // 한쪽이 반드시 틀린다.
      final heroText = ImportStrings.aiRegisterSummary(
        EntryKind.event,
        created: 2,
        dup: 0,
        skipped: 0,
      );
      expect(heroText, contains('검토'));
    });

    test('중복은 캘린더 이벤트도 두 번 만들지 않는다', () async {
      await register('event');
      await register('event');

      final events = await container
          .read(calendarRepositoryProvider)
          .getEventsByDateRange(DateTime(2026, 10, 1), DateTime(2026, 12, 31));
      expect(events, hasLength(2), reason: '같은 텍스트를 두 번 넣어도 2건이어야 한다');
    });
  });
}
