import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/utils/date_utils.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/notifications/presentation/providers/notification_providers.dart';
import 'package:planroutine/features/today/domain/today_view.dart';
import 'package:planroutine/features/today/presentation/providers/today_providers.dart';

import '../../helpers/test_database.dart';

final _today = DateTime(2026, 7, 25);

/// sync 호출 횟수를 세고, gate가 열릴 때까지 첫 호출을 붙잡아 두는 테스트용 syncer.
class _GatedSyncer extends NotificationSyncer {
  _GatedSyncer(super.ref);

  int calls = 0;
  Completer<void>? gate;

  @override
  Future<void> sync() async {
    calls++;
    final pending = gate;
    if (pending != null) await pending.future;
  }
}

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late CalendarRepository repository;
  late ProviderContainer container;

  setUp(() {
    // in-memory DB는 close할 때까지 같은 인스턴스가 재사용된다 → 테스트마다 닫아야 격리된다.
    db = freshDatabaseHelper();
    repository = CalendarRepository(dbHelper: db);
    container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repository),
        todayReferenceProvider.overrideWithValue(_today),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// 오늘 탭 화면 진입을 모사한다.
  ///
  /// todayViewProvider는 autoDispose라 구독자가 없으면 read 직후 폐기된다. 화면이
  /// 떠 있는 동안만 상태가 유지되는 실제 동작과 같으므로, 리스너로 붙잡은 뒤 첫 조회를
  /// 기다린다. (setUp에서 붙잡으면 데이터 삽입 전에 build가 돌아 빈 결과가 캐시된다.)
  Future<TodayView> openTodayTab() {
    container.listen(todayViewProvider, (_, _) {});
    return container.read(todayViewProvider.future);
  }

  Future<int> insert(String title, DateTime date) {
    return repository.createEvent(
      CalendarEvent(title: title, eventDate: formatDate(date)),
    );
  }

  group('todayViewProvider — 조회', () {
    test('오늘 이벤트와 컷오프 안의 지난 이벤트를 나눠 담는다', () async {
      await insert('오늘 업무', _today);
      await insert('지난 업무', _today.subtract(const Duration(days: 2)));
      await insert('컷오프 밖', _today.subtract(const Duration(days: 30)));

      final view = await openTodayTab();

      expect(view.today.map((e) => e.title), ['오늘 업무']);
      expect(view.overdue.map((e) => e.title), ['지난 업무']);
    });

    test('삭제된(휴지통) 이벤트는 나오지 않는다', () async {
      final id = await insert('삭제된 업무', _today);
      await repository.deleteEvent(id);

      final view = await openTodayTab();

      expect(view.today, isEmpty);
    });
  });

  group('캘린더 탭 변경 반영', () {
    test('캘린더에서 오늘 일정을 추가하면 오늘 탭 목록에 나타난다', () async {
      final view = await openTodayTab();
      expect(view.today, isEmpty);

      // 캘린더 탭이 쓰는 경로로 추가 (EventEditDialog 저장과 동일)
      await container.read(selectedMonthEventsProvider.notifier).addEvent(
            CalendarEvent(title: '새 학년 준비 회의', eventDate: formatDate(_today)),
          );

      final next = await container.read(todayViewProvider.future);
      expect(next.today.map((e) => e.title), ['새 학년 준비 회의']);
    });

    test('캘린더에서 이벤트를 삭제하면 오늘 탭에서도 사라진다', () async {
      final id = await insert('삭제될 일정', _today);
      final view = await openTodayTab();
      expect(view.today, hasLength(1));

      await container.read(selectedMonthEventsProvider.notifier).deleteEvent(id);

      final next = await container.read(todayViewProvider.future);
      expect(next.today, isEmpty);
    });
  });

  group('알림 재예약 합치기', () {
    test('sync가 진행 중이면 연속 토글이 한 번으로 합쳐진다', () async {
      final gated = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repository),
          todayReferenceProvider.overrideWithValue(_today),
          notificationSyncerProvider.overrideWith(_GatedSyncer.new),
        ],
      );
      addTearDown(gated.dispose);
      final syncer =
          gated.read(notificationSyncerProvider) as _GatedSyncer;

      await insert('첫째 업무', _today);
      await insert('둘째 업무', _today);
      await insert('셋째 업무', _today);
      // 리스너는 seed 뒤에 붙인다 — 먼저 붙이면 빈 결과가 캐시된다.
      gated.listen(todayViewProvider, (_, _) {});
      final view = await gated.read(todayViewProvider.future);
      final notifier = gated.read(todayViewProvider.notifier);

      syncer.gate = Completer<void>();

      // 1) 첫 토글 → sync가 실제로 gate에 걸릴 때까지 기다린다.
      final first = notifier.toggleCompleted(view.today[0]);
      while (syncer.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      // 2) sync가 진행 중인 동안 두 번 더 토글 (DB 쓰기까지 끝낼 시간을 준다)
      final second = notifier.toggleCompleted(view.today[1]);
      final third = notifier.toggleCompleted(view.today[2]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 3) gate를 열면 밀린 요청이 한 번으로 합쳐져 재실행된다.
      syncer.gate!.complete();
      await Future.wait([first, second, third]);

      // 진행 중이던 1회 + 합쳐진 재실행 1회 = 2회 (합치지 않으면 3회)
      expect(syncer.calls, 2);
    });
  });

  group('TodayViewNotifier.toggleCompleted', () {
    test('완료로 토글하면 DB에 완료 시각이 기록된다', () async {
      await insert('출결 마감 확인', _today);
      final view = await openTodayTab();

      await container
          .read(todayViewProvider.notifier)
          .toggleCompleted(view.today.first);

      final stored = await repository.getEventsByDate(_today);
      expect(stored.single.isCompleted, isTrue);
    });

    test('완료된 항목을 다시 토글하면 완료 시각이 지워진다', () async {
      final id = await insert('출결 마감 확인', _today);
      await repository.markCompleted(id);
      final view = await openTodayTab();

      await container
          .read(todayViewProvider.notifier)
          .toggleCompleted(view.today.first);

      final stored = await repository.getEventsByDate(_today);
      expect(stored.single.isCompleted, isFalse);
    });

    test('토글해도 목록 순서가 그대로 유지된다 (재정렬하지 않는다)', () async {
      await insert('첫째 업무', _today);
      await insert('둘째 업무', _today);
      final view = await openTodayTab();

      await container
          .read(todayViewProvider.notifier)
          .toggleCompleted(view.today.first);

      final next = container.read(todayViewProvider).requireValue;
      expect(next.today.map((e) => e.title), ['첫째 업무', '둘째 업무']);
      expect(next.today.first.isCompleted, isTrue);
      expect(next.doneCount, 1);
    });

    test('지난 항목을 완료해도 지난 목록에 남는다', () async {
      await insert('지난 업무', _today.subtract(const Duration(days: 3)));
      final view = await openTodayTab();

      await container
          .read(todayViewProvider.notifier)
          .toggleCompleted(view.overdue.first);

      final next = container.read(todayViewProvider).requireValue;
      expect(next.overdue.single.isCompleted, isTrue);
    });
  });
}
