import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/notifications/data/notification_rules.dart';
import 'package:planroutine/features/notifications/domain/notification_settings.dart';

CalendarEvent event({
  required int id,
  required String date,
  String title = '회의',
  bool important = false,
  String? deletedAt,
  String? completedAt,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    eventDate: date,
    isImportant: important,
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

    test('활성 이벤트가 하나도 없으면 빈 알림도 만들지 않음', () {
      final result = computeNotifications(
        events: const [],
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
          event(id: 1, date: '2026-06-10', title: '가'),
          event(id: 2, date: '2026-06-20', title: '나'),
          event(id: 3, date: '2026-07-05', title: '다'),
        ],
        settings: master.copyWith(
          weekBeforeEnabled: false,
          dayBeforeEnabled: false,
        ),
        now: now,
      );
      // 6월, 7월 월초 2건
      expect(result.length, 2);
      // 이달 섹션은 총 건수 표기 (중요표시 없으면 제목 미노출)
      expect(
        result.any((p) =>
            p.scheduledAt == DateTime(2026, 6, 1, 8) &&
            p.body.contains('이달') &&
            p.body.contains('총 2건')),
        isTrue,
      );
      expect(
        result.any((p) =>
            p.scheduledAt == DateTime(2026, 7, 1, 8) &&
            p.body.contains('이달') &&
            p.body.contains('총 1건')),
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
    test('이벤트 1주 전 + 1일 전 각각 다른 날짜에 1개씩', () {
      final result = computeNotifications(
        events: [event(id: 42, date: '2026-06-01', title: '연수')],
        settings: master.copyWith(monthStartEnabled: false),
        now: now,
      );
      expect(result.length, 2);
      // 1주 전 = 5/25 08:00, 1일 전 = 5/31 08:00
      expect(
        result.any((p) =>
            p.scheduledAt == DateTime(2026, 5, 25, 8) &&
            p.body.contains('1주 후') &&
            p.body.contains('연수')),
        isTrue,
      );
      expect(
        result.any((p) =>
            p.scheduledAt == DateTime(2026, 5, 31, 8) &&
            p.body.contains('내일') &&
            p.body.contains('연수')),
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
      expect(result.first.body, contains('1주 후'));
    });
  });

  group('하루 통합 (버그 픽스)', () {
    test('같은 날짜 이벤트 3건 → 1일 전 알림은 1개로 통합', () {
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-10', title: '가'),
          event(id: 2, date: '2026-06-10', title: '나'),
          event(id: 3, date: '2026-06-10', title: '다'),
        ],
        settings: master.copyWith(
          monthStartEnabled: false,
          weekBeforeEnabled: false,
        ),
        now: now,
      );
      // 1일 전 발송일(6/9)에 알림 딱 1개
      final atFireDay = result
          .where((p) => p.scheduledAt == DateTime(2026, 6, 9, 8))
          .toList();
      expect(atFireDay.length, 1);
      // 본문에 3건이 압축돼 반영: 제목 2개 노출 + "외 1건"
      final body = atFireDay.first.body;
      expect(body, contains('내일'));
      expect(body, contains('가'));
      expect(body, contains('나'));
      expect(body, contains('외 1건'));
    });

    test('같은 날 1일 전 + 월초가 겹치면 한 알림에 병합', () {
      // event 6/2 → 1일 전 발송 6/1, June 월초도 6/1 → 병합
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-02', title: '연수')],
        settings: master.copyWith(weekBeforeEnabled: false),
        now: now,
      );
      final atJune1 = result
          .where((p) => p.scheduledAt == DateTime(2026, 6, 1, 8))
          .toList();
      expect(atJune1.length, 1);
      final body = atJune1.first.body;
      expect(body, contains('내일'));
      expect(body, contains('이달'));
    });

    test('본문 섹션 순서: 내일 → 1주 후 → 이달', () {
      // 6/1 발송에 내일(6/2)·1주 후(6/8)·이달(June) 모두 얹히도록 구성
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-02', title: '내일건'),
          event(id: 2, date: '2026-06-08', title: '주간건'),
        ],
        settings: master,
        now: now,
      );
      final atJune1 = result
          .firstWhere((p) => p.scheduledAt == DateTime(2026, 6, 1, 8));
      final body = atJune1.body;
      final iTomorrow = body.indexOf('내일');
      final iWeek = body.indexOf('1주 후');
      final iMonth = body.indexOf('이달');
      expect(iTomorrow, greaterThanOrEqualTo(0));
      expect(iWeek, greaterThan(iTomorrow));
      expect(iMonth, greaterThan(iWeek));
    });

    test('많은 이벤트는 "외 N건"으로 압축', () {
      final result = computeNotifications(
        events: [
          for (var i = 0; i < 5; i++)
            event(id: i + 1, date: '2026-06-10', title: '건${String.fromCharCode(0xAC00 + i)}'),
        ],
        settings: master.copyWith(
          monthStartEnabled: false,
          weekBeforeEnabled: false,
        ),
        now: now,
      );
      final body = result
          .firstWhere((p) => p.scheduledAt == DateTime(2026, 6, 9, 8))
          .body;
      // 5건 → 제목 2개 + "외 3건"
      expect(body, contains('외 3건'));
    });
  });

  group('이달 섹션 (개수 + 중요표시)', () {
    test('이달 섹션은 총 건수 + 중요표시된 이벤트 제목만 노출', () {
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-05', title: '일반건'),
          event(id: 2, date: '2026-06-10', title: '중요건', important: true),
          event(id: 3, date: '2026-06-15', title: '또일반'),
        ],
        settings: master.copyWith(
          weekBeforeEnabled: false,
          dayBeforeEnabled: false,
        ),
        now: now,
      );
      final body = result
          .firstWhere((p) => p.scheduledAt == DateTime(2026, 6, 1, 8))
          .body;
      expect(body, contains('총 3건'));
      expect(body, contains('중요건'));
      expect(body, isNot(contains('일반건')));
      expect(body, isNot(contains('또일반')));
    });

    test('중요표시가 없으면 이달 섹션은 총 건수만', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-05', title: '일반건')],
        settings: master.copyWith(
          weekBeforeEnabled: false,
          dayBeforeEnabled: false,
        ),
        now: now,
      );
      final body = result
          .firstWhere((p) => p.scheduledAt == DateTime(2026, 6, 1, 8))
          .body;
      expect(body, contains('총 1건'));
      expect(body, isNot(contains('일반건')));
    });

    test('이달 중요표시 제목은 가장 임박한 순으로 정렬', () {
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-25', title: '나중중요', important: true),
          event(id: 2, date: '2026-06-05', title: '먼저중요', important: true),
        ],
        settings: master.copyWith(
          weekBeforeEnabled: false,
          dayBeforeEnabled: false,
        ),
        now: now,
      );
      final body = result
          .firstWhere((p) => p.scheduledAt == DateTime(2026, 6, 1, 8))
          .body;
      expect(body.indexOf('먼저중요'), lessThan(body.indexOf('나중중요')));
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
    test('서로 다른 발송 날짜의 알림은 서로 다른 id', () {
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
