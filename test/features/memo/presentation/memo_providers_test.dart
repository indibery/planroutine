import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/module_catalog.dart';
import 'package:planroutine/core/modules/installed_modules_provider.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/memo/data/memo_repository.dart';
import 'package:planroutine/features/memo/presentation/providers/memo_providers.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/module_prefs.dart';
import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;

  ProviderContainer container({bool installed = true}) {
    SharedPreferences.setMockInitialValues(
      modulePrefs(installed: [if (installed) ModuleIds.memo]),
    );
    final c = ProviderContainer(
      overrides: [
        // 등록부에 쪽지 기능이 들어오기(Task 6) 전이라 테스트가 직접 주입한다.
        moduleCatalogProvider.overrideWithValue([
          ...moduleCatalog,
          const AppModule(
            id: ModuleIds.memo,
            name: '쪽지',
            icon: Icons.sticky_note_2_outlined,
            placement: ModulePlacement.todayCard,
          ),
        ]),
        memoRepositoryProvider.overrideWithValue(MemoRepository(dbHelper: db)),
        calendarRepositoryProvider.overrideWithValue(
          CalendarRepository(dbHelper: db),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => db = freshDatabaseHelper());
  tearDown(() async => db.close());

  test('빈 글은 붙지 않는다', () async {
    final c = container();
    await c.read(memosProvider.future);
    await c.read(memosProvider.notifier).add('   ');
    expect(await c.read(memosProvider.future), isEmpty);
  });

  test('붙이면 맨 앞에 보인다', () async {
    final c = container();
    await c.read(memosProvider.future);
    final n = c.read(memosProvider.notifier);
    await n.add('첫째');
    await n.add('둘째');
    expect((await c.read(memosProvider.future)).map((m) => m.text), [
      '둘째',
      '첫째',
    ]);
  });

  test('옮기면 저장소 순서까지 바뀐다 — 다시 읽어도 그대로', () async {
    final c = container();
    await c.read(memosProvider.future);
    final n = c.read(memosProvider.notifier);
    await n.add('a');
    await n.add('b');
    await n.add('c'); // 순서 c, b, a
    final a = (await c.read(memosProvider.future)).last;
    await n.move(a.id ?? -1, 0);
    final fresh = await MemoRepository(dbHelper: db).getActive();
    expect(fresh.map((m) => m.text), ['a', 'c', 'b']);
  });

  test('일정으로 바꾸면 확정 일정이 생기고 쪽지는 휴지통으로 간다', () async {
    final c = container();
    await c.read(memosProvider.future);
    final n = c.read(memosProvider.notifier);
    await n.add('운동회 물품 확인');
    final memo = (await c.read(memosProvider.future)).single;
    await n.convertToEvent(
      memo,
      kind: EntryKind.event,
      date: DateTime(2026, 10, 24),
    );

    final events = await CalendarRepository(
      dbHelper: db,
    ).getEventsByMonth(2026, 10);
    expect(events.single.title, '운동회 물품 확인');
    expect(events.single.kind, EntryKind.event);
    expect(events.single.eventDate, '2026-10-24');
    expect(events.single.scheduleId, isNull);
    expect(await c.read(memosProvider.future), isEmpty);
    expect(await MemoRepository(dbHelper: db).getDeleted(), hasLength(1));
  });

  test('캘린더용 조회는 그 달의 날짜 붙은 쪽지를 날짜별로 묶는다', () async {
    final c = container();
    await c.read(memosProvider.future);
    final n = c.read(memosProvider.notifier);
    await n.add('지도안');
    final m = (await c.read(memosProvider.future)).single;
    await n.save(m.copyWith(memoDate: DateTime(2026, 10, 17)));
    // 등록부가 로딩 중이면 moduleInstalledProvider가 false다 — 먼저 읽어 둔다.
    await c.read(installedModulesProvider.future);
    final map = await c.read(
      monthMemosByDateProvider((year: 2026, month: 10)).future,
    );
    expect(map.keys, ['2026-10-17']);
    expect(map['2026-10-17']?.single.text, '지도안');
  });

  test('기능이 꺼져 있으면 캘린더용 조회는 비어 있다 — 데이터는 남는다', () async {
    final c = container(installed: false);
    final repo = MemoRepository(dbHelper: db);
    final m = await repo.add('남아 있음');
    await repo.update(m.copyWith(memoDate: DateTime(2026, 10, 17)));
    final map = await c.read(
      monthMemosByDateProvider((year: 2026, month: 10)).future,
    );
    expect(map, isEmpty);
    expect(await repo.getActive(), hasLength(1));
  });
}
