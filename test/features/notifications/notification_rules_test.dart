import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/notifications/data/notification_rules.dart';
import 'package:planroutine/features/notifications/domain/notification_settings.dart';

CalendarEvent event({
  required int id,
  required String date,
  String title = '회의',
  String? deletedAt,
  String? completedAt,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    eventDate: date,
    deletedAt: deletedAt,
    completedAt: completedAt,
  );
}

void main() {
  // 테스트 now: 2026-05-15 10:00 — 5월 중순
  final now = DateTime(2026, 5, 15, 10, 0);
  const master = NotificationSettings(masterEnabled: true);

  group('masterEnabled', () {
    test('masterEnabled=false면 이벤트가 있어도 빈 리스트', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-10')],
        settings: const NotificationSettings(masterEnabled: false),
        now: now,
      );
      expect(result, isEmpty);
    });

    test('masterEnabled=true + 기본 세부 ON → 예약 생성', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-10')],
        settings: master,
        now: now,
      );
      expect(result, isNotEmpty);
    });
  });

  group('이벤트 필터링', () {
    test('completed 이벤트는 대상 제외', () {
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-10', completedAt: '2026-05-01T10:00:00'),
        ],
        settings: master,
        now: now,
      );
      expect(result, isEmpty);
    });

    test('deleted 이벤트는 대상 제외', () {
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-10', deletedAt: '2026-05-01T10:00:00'),
        ],
        settings: master,
        now: now,
      );
      expect(result, isEmpty);
    });

    test('과거 시점 알림은 생성 안 됨', () {
      // 어제 이벤트 — 1일 전 알림은 2일 전, 이미 과거
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-05-14')],
        settings: master,
        now: now,
      );
      expect(result, isEmpty);
    });
  });

  group('월초 알림', () {
    test('활성 이벤트가 있는 달마다 1개', () {
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-10'),
          event(id: 2, date: '2026-06-20'),
          event(id: 3, date: '2026-07-05'),
        ],
        settings: master.copyWith(
          weekBeforeEnabled: false,
          dayBeforeEnabled: false,
        ),
        now: now,
      );
      // 6월, 7월 월초 2건
      expect(result.length, 2);
      expect(
        result.any((p) =>
            p.scheduledAt == DateTime(2026, 6, 1, 8) &&
            p.body.contains('2건')),
        isTrue,
      );
      expect(
        result.any((p) =>
            p.scheduledAt == DateTime(2026, 7, 1, 8) &&
            p.body.contains('1건')),
        isTrue,
      );
    });

    test('이미 지난 이번달 1일은 생성 안 됨 (now=5/15 → 5/1 과거)', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-05-25')], // 이번 달 이벤트
        settings: master.copyWith(
          weekBeforeEnabled: false,
          dayBeforeEnabled: false,
        ),
        now: now,
      );
      expect(result, isEmpty); // 5/1은 과거
    });

    test('monthStartEnabled=false면 월초 알림 생성 안 됨', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-10')],
        settings: master.copyWith(
          monthStartEnabled: false,
          weekBeforeEnabled: false,
          dayBeforeEnabled: false,
        ),
        now: now,
      );
      expect(result, isEmpty);
    });
  });

  group('1주 전 / 1일 전 알림', () {
    test('이벤트 1주 전 + 1일 전 각각 1개씩 생성', () {
      final result = computeNotifications(
        events: [event(id: 42, date: '2026-06-01', title: '연수')],
        settings: master.copyWith(monthStartEnabled: false),
        now: now,
      );
      expect(result.length, 2);
      // 1주 전 = 5/25 09:00, 1일 전 = 5/31 09:00
      expect(
        result.any((p) =>
            p.scheduledAt == DateTime(2026, 5, 25, 8) &&
            p.body.contains('1주 남았')),
        isTrue,
      );
      expect(
        result.any((p) =>
            p.scheduledAt == DateTime(2026, 5, 31, 8) &&
            p.body.contains('내일')),
        isTrue,
      );
    });

    test('weekBefore=false면 1주 전 알림 생성 안 됨', () {
      final result = computeNotifications(
        events: [event(id: 42, date: '2026-06-01')],
        settings: master.copyWith(
          monthStartEnabled: false,
          weekBeforeEnabled: false,
        ),
        now: now,
      );
      expect(result.length, 1);
      expect(result.first.body, contains('내일'));
    });

    test('dayBefore=false면 1일 전 알림 생성 안 됨', () {
      final result = computeNotifications(
        events: [event(id: 42, date: '2026-06-01')],
        settings: master.copyWith(
          monthStartEnabled: false,
          dayBeforeEnabled: false,
        ),
        now: now,
      );
      expect(result.length, 1);
      expect(result.first.body, contains('1주 남았'));
    });
  });

  group('iOS 64개 상한', () {
    test('이벤트가 많아도 결과가 kMaxPendingNotifications(60) 이하', () {
      final events = List.generate(
        40, // 40개 × (주/일) 2개 = 80개 + 월초
        (i) => event(
          id: i + 1,
          date: DateTime(2026, 6, 1).add(Duration(days: i)).toIso8601String().substring(0, 10),
        ),
      );
      final result = computeNotifications(
        events: events,
        settings: master,
        now: now,
      );
      expect(result.length, lessThanOrEqualTo(kMaxPendingNotifications));
    });

    test('절단 시 시각 오름차순으로 가까운 것 우선', () {
      final events = List.generate(
        40,
        (i) => event(
          id: i + 1,
          date: DateTime(2026, 7, 1)
              .add(Duration(days: i))
              .toIso8601String()
              .substring(0, 10),
        ),
      );
      final result = computeNotifications(
        events: events,
        settings: master,
        now: now,
      );
      // 시간 오름차순 정렬 확인
      for (var i = 1; i < result.length; i++) {
        expect(
          result[i].scheduledAt.isAtSameMomentAs(result[i - 1].scheduledAt) ||
              result[i].scheduledAt.isAfter(result[i - 1].scheduledAt),
          isTrue,
        );
      }
    });
  });

  group('id 유일성', () {
    test('동일 이벤트의 1주/1일 알림은 서로 다른 id', () {
      final result = computeNotifications(
        events: [event(id: 42, date: '2026-06-01')],
        settings: master.copyWith(monthStartEnabled: false),
        now: now,
      );
      final ids = result.map((p) => p.id).toSet();
      expect(ids.length, result.length);
    });

    test('다른 월의 월초 알림은 서로 다른 id', () {
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-10'),
          event(id: 2, date: '2026-07-05'),
        ],
        settings: master.copyWith(
          weekBeforeEnabled: false,
          dayBeforeEnabled: false,
        ),
        now: now,
      );
      final ids = result.map((p) => p.id).toSet();
      expect(ids.length, result.length);
    });
  });
}
