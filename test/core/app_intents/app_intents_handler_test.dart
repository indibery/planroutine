// 단축어에서 들어오는 호출을 처리하는 핸들러.
//
// **핸들러는 위임만 한다** — 파싱·중복체크·요약은 각자 자기 테스트가 있고,
// 여기서 보는 것은 "인자를 옳게 풀어 넘기고 결과를 옳게 돌려주는가"다.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/app_intents/app_intents_contract.dart';
import 'package:planroutine/core/app_intents/app_intents_handler.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
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
}
