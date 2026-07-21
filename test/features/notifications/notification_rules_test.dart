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
  // 테스트 now: 2026-05-15(금) 10:00. 2026-06-01은 월요일.
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

    test('완전히 과거인 이벤트는 아무 알림도 안 만듦', () {
      // 어제(5/14 목) 이벤트 — 당일·월요일종합·월초 모두 이미 과거
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-05-14')],
        settings: master,
        now: now,
      );
      expect(result, isEmpty);
    });
  });

  group('당일 아침', () {
    test('이벤트 당일 08:00에 오늘 섹션 1건', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-03', title: '수요건')],
        settings: master.copyWith(monthStartEnabled: false, weeklyEnabled: false),
        now: now,
      );
      expect(result.length, 1);
      expect(result.first.scheduledAt, DateTime(2026, 6, 3, 8));
      expect(result.first.body, contains('오늘'));
      expect(result.first.body, contains('수요건'));
    });

    test('dayOf=false면 오늘 섹션 없음', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-03')],
        settings: master.copyWith(
          monthStartEnabled: false,
          weeklyEnabled: false,
          dayOfEnabled: false,
        ),
        now: now,
      );
      expect(result, isEmpty);
    });

    test('이벤트가 오늘이고 08시가 이미 지났으면 미발송', () {
      // now=5/15 10:00 → 오늘(5/15) 08:00은 과거
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-05-15')],
        settings: master.copyWith(monthStartEnabled: false, weeklyEnabled: false),
        now: now,
      );
      expect(result, isEmpty);
    });

    test('이벤트가 오늘이고 아직 08시 전이면 발송', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-05-15', title: '조회')],
        settings: master.copyWith(monthStartEnabled: false, weeklyEnabled: false),
        now: DateTime(2026, 5, 15, 7, 0),
      );
      expect(result.length, 1);
      expect(result.first.scheduledAt, DateTime(2026, 5, 15, 8));
      expect(result.first.body, contains('오늘'));
      expect(result.first.body, contains('조회'));
    });
  });

  group('월요일 이번 주 종합', () {
    test('그 주 화~일 이벤트가 월요일 08:00 한 건으로 통합', () {
      // 6/2(화)·6/4(목) → 6/1(월) 08:00 "이번 주"
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-02', title: '화건'),
          event(id: 2, date: '2026-06-04', title: '목건'),
        ],
        settings: master.copyWith(monthStartEnabled: false, dayOfEnabled: false),
        now: now,
      );
      final mon =
          result.where((p) => p.scheduledAt == DateTime(2026, 6, 1, 8)).toList();
      expect(mon.length, 1);
      expect(mon.first.body, contains('이번 주'));
      expect(mon.first.body, contains('화건'));
      expect(mon.first.body, contains('목건'));
    });

    test('월요일 당일 이벤트는 이번 주 섹션에서 제외 (오늘이 담당)', () {
      // 6/1(월) 이벤트 + dayOf off → 이번 주에도 안 들어가 결과 없음
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-01', title: '월건')],
        settings: master.copyWith(monthStartEnabled: false, dayOfEnabled: false),
        now: now,
      );
      expect(result, isEmpty);
    });

    test('weekly=false면 이번 주 종합 없음', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-02')],
        settings: master.copyWith(
          monthStartEnabled: false,
          dayOfEnabled: false,
          weeklyEnabled: false,
        ),
        now: now,
      );
      expect(result, isEmpty);
    });

    test('다른 주 이벤트는 각자의 월요일로 묶임', () {
      // 6/2(화)→6/1(월), 6/9(화)→6/8(월)
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-02'),
          event(id: 2, date: '2026-06-09'),
        ],
        settings: master.copyWith(monthStartEnabled: false, dayOfEnabled: false),
        now: now,
      );
      final dates = result.map((p) => p.scheduledAt).toSet();
      expect(dates.contains(DateTime(2026, 6, 1, 8)), isTrue);
      expect(dates.contains(DateTime(2026, 6, 8, 8)), isTrue);
      expect(result.length, 2);
    });

    test('그 주 월요일이 이미 지났으면 미발송 (이벤트가 미래라도)', () {
      // now=5/15(금). 이벤트 5/16(토) → weekMonday 5/11(월) 과거
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-05-16')],
        settings: master.copyWith(monthStartEnabled: false, dayOfEnabled: false),
        now: now,
      );
      expect(result, isEmpty);
    });

    test('이번 주 항목이 많으면 "외 N건"으로 압축', () {
      // 6/2~6/6 (화~토) 5건 → 제목 2개 + 외 3건
      final result = computeNotifications(
        events: [
          for (var i = 0; i < 5; i++)
            event(
              id: i + 1,
              date: '2026-06-0${i + 2}',
              title: '건${String.fromCharCode(0xAC00 + i)}',
            ),
        ],
        settings: master.copyWith(monthStartEnabled: false, dayOfEnabled: false),
        now: now,
      );
      final body = result
          .firstWhere((p) => p.scheduledAt == DateTime(2026, 6, 1, 8))
          .body;
      expect(body, contains('외 3건'));
    });
  });

  group('월초', () {
    test('이벤트가 있는 달마다 1일 08:00, 이달 — N건', () {
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-10', title: '가'),
          event(id: 2, date: '2026-06-20', title: '나'),
          event(id: 3, date: '2026-07-05', title: '다'),
        ],
        settings: master.copyWith(weeklyEnabled: false, dayOfEnabled: false),
        now: now,
      );
      expect(result.length, 2);
      expect(
        result.any((p) =>
            p.scheduledAt == DateTime(2026, 6, 1, 8) &&
            p.body.contains('이달') &&
            p.body.contains('2건')),
        isTrue,
      );
      expect(
        result.any((p) =>
            p.scheduledAt == DateTime(2026, 7, 1, 8) && p.body.contains('1건')),
        isTrue,
      );
    });

    test('이미 지난 이번달 1일은 미발송 (now=5/15 → 5/1 과거)', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-05-25')],
        settings: master.copyWith(weeklyEnabled: false, dayOfEnabled: false),
        now: now,
      );
      expect(result, isEmpty);
    });

    test('monthStart=false면 월초 알림 없음', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-10')],
        settings: master.copyWith(
          monthStartEnabled: false,
          weeklyEnabled: false,
          dayOfEnabled: false,
        ),
        now: now,
      );
      expect(result, isEmpty);
    });

    test('이달 섹션은 총 건수 + 중요 개수만 표기 (제목 미노출)', () {
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-05', title: '일반건'),
          event(id: 2, date: '2026-06-10', title: '중요건', important: true),
          event(id: 3, date: '2026-06-15', title: '중요둘', important: true),
        ],
        settings: master.copyWith(weeklyEnabled: false, dayOfEnabled: false),
        now: now,
      );
      final body = result
          .firstWhere((p) => p.scheduledAt == DateTime(2026, 6, 1, 8))
          .body;
      expect(body, contains('3건'));
      expect(body, contains('(중요 2)'));
      expect(body, isNot(contains('중요건')));
      expect(body, isNot(contains('일반건')));
    });

    test('중요표시가 없으면 (중요 …) 생략', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-05', title: '일반건')],
        settings: master.copyWith(weeklyEnabled: false, dayOfEnabled: false),
        now: now,
      );
      final body = result
          .firstWhere((p) => p.scheduledAt == DateTime(2026, 6, 1, 8))
          .body;
      expect(body, contains('1건'));
      expect(body, isNot(contains('중요')));
    });
  });

  group('월요일 통합 (오늘 + 이번 주 + 이달)', () {
    test('세 섹션이 한 알림에 병합', () {
      // 6/1(월): 오늘=6/1, 이번 주=6/3, 이달=6월(1일)
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-01', title: '월건'),
          event(id: 2, date: '2026-06-03', title: '수건'),
        ],
        settings: master,
        now: now,
      );
      final mon =
          result.firstWhere((p) => p.scheduledAt == DateTime(2026, 6, 1, 8));
      expect(mon.body, contains('오늘'));
      expect(mon.body, contains('월건'));
      expect(mon.body, contains('이번 주'));
      expect(mon.body, contains('수건'));
      expect(mon.body, contains('이달'));
    });

    test('본문 섹션 순서: 오늘 → 이번 주 → 이달', () {
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-01', title: '오늘건'),
          event(id: 2, date: '2026-06-03', title: '주간건'),
        ],
        settings: master,
        now: now,
      );
      final body = result
          .firstWhere((p) => p.scheduledAt == DateTime(2026, 6, 1, 8))
          .body;
      final iToday = body.indexOf('오늘');
      final iWeek = body.indexOf('이번 주');
      final iMonth = body.indexOf('이달');
      expect(iToday, greaterThanOrEqualTo(0));
      expect(iWeek, greaterThan(iToday));
      expect(iMonth, greaterThan(iWeek));
    });
  });

  group('본문 형식 (이모지 스캔형)', () {
    test('오늘/이번 주/이달에 이모지 프리픽스', () {
      final result = computeNotifications(
        events: [
          event(id: 1, date: '2026-06-01', title: '월건'),
          event(id: 2, date: '2026-06-03', title: '수건'),
        ],
        settings: master,
        now: now,
      );
      final body = result
          .firstWhere((p) => p.scheduledAt == DateTime(2026, 6, 1, 8))
          .body;
      expect(body, contains('📅 오늘'));
      expect(body, contains('🗓 이번 주'));
      expect(body, contains('📌 이달'));
    });

    test('알림 제목은 "일정 알림"', () {
      final result = computeNotifications(
        events: [event(id: 1, date: '2026-06-03')],
        settings: master.copyWith(monthStartEnabled: false, weeklyEnabled: false),
        now: now,
      );
      expect(result.first.title, '일정 알림');
    });
  });

  group('iOS 64개 상한', () {
    test('이벤트가 많아도 결과가 kMaxPendingNotifications(60) 이하', () {
      final events = List.generate(
        40,
        (i) => event(
          id: i + 1,
          date: DateTime(2026, 6, 1)
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
      expect(result.length, lessThanOrEqualTo(kMaxPendingNotifications));
    });

    test('distinct 발송일이 60을 넘으면 60개로 절단 + 가까운 것 우선', () {
      // 각기 다른 70개 미래 날짜 → 당일 알림만 70개 distinct 발송일 → 60 절단
      final events = List.generate(
        70,
        (i) => event(
          id: i + 1,
          date: DateTime(2026, 6, 1)
              .add(Duration(days: i))
              .toIso8601String()
              .substring(0, 10),
        ),
      );
      final result = computeNotifications(
        events: events,
        settings: master.copyWith(monthStartEnabled: false, weeklyEnabled: false),
        now: now,
      );
      expect(result.length, kMaxPendingNotifications); // 60
      // 가까운 것 우선 → 가장 이른 6/1이 남고, 뒤쪽(8월)은 잘림
      expect(result.first.scheduledAt, DateTime(2026, 6, 1, 8));
      expect(
        result.every((p) => !p.scheduledAt.isAfter(DateTime(2026, 7, 30, 8))),
        isTrue,
      );
    });

    test('시각 오름차순으로 가까운 것 우선 정렬', () {
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
        events: [event(id: 42, date: '2026-06-02')],
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
        settings: master.copyWith(weeklyEnabled: false, dayOfEnabled: false),
        now: now,
      );
      final ids = result.map((p) => p.id).toSet();
      expect(ids.length, result.length);
    });
  });
}
