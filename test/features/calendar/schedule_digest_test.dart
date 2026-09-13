// 단축어가 돌려받는 텍스트를 만드는 순수 함수.
// DB도 플랫폼도 타지 않으므로 경계값을 직접 박아 고정한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/domain/schedule_digest.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';

CalendarEvent _event(
  String title,
  String date, {
  EntryKind kind = EntryKind.task,
  String? completedAt,
}) => CalendarEvent(
  title: title,
  eventDate: date,
  kind: kind,
  completedAt: completedAt,
);

void main() {
  // 2026-09-16은 수요일이다.
  final wednesday = DateTime(2026, 9, 16, 10, 30);

  group('digestBounds', () {
    test('오늘은 그날 하루다', () {
      final b = digestBounds(wednesday, DigestRange.today);
      expect(b.start, DateTime(2026, 9, 16));
      expect(b.end, DateTime(2026, 9, 16));
    });

    test('이번 주는 월요일부터 일요일까지다', () {
      final b = digestBounds(wednesday, DigestRange.thisWeek);
      expect(b.start, DateTime(2026, 9, 14), reason: '월요일');
      expect(b.end, DateTime(2026, 9, 20), reason: '일요일');
    });

    test('이번 달은 1일부터 말일까지다', () {
      final b = digestBounds(wednesday, DigestRange.thisMonth);
      expect(b.start, DateTime(2026, 9, 1));
      expect(b.end, DateTime(2026, 9, 30), reason: '9월은 30일까지');
    });

    test('2월 말일을 윤년까지 맞춘다', () {
      final b = digestBounds(DateTime(2028, 2, 10), DigestRange.thisMonth);
      expect(b.end, DateTime(2028, 2, 29));
    });
  });

  group('buildScheduleDigest', () {
    test('비었으면 없다고 말한다', () {
      final text = buildScheduleDigest(
        events: const [],
        now: wednesday,
        range: DigestRange.today,
      );
      expect(text, contains('없'));
    });

    test('날짜순으로 제목을 담는다', () {
      final text = buildScheduleDigest(
        events: [_event('학예회', '2026-09-18'), _event('운동회', '2026-09-16')],
        now: wednesday,
        range: DigestRange.thisWeek,
      );
      expect(text.indexOf('운동회'), lessThan(text.indexOf('학예회')));
    });

    test('완료한 항목을 표시한다', () {
      final text = buildScheduleDigest(
        events: [
          _event('제출', '2026-09-16', completedAt: '2026-09-16T09:00:00'),
        ],
        now: wednesday,
        range: DigestRange.today,
      );
      expect(text, contains('제출'));
      expect(text, contains('완료'));
    });

    test('업무와 행사를 종류로 구분해 적는다', () {
      final text = buildScheduleDigest(
        events: [
          _event('공문 제출', '2026-09-16'),
          _event('운동회', '2026-09-16', kind: EntryKind.event),
        ],
        now: wednesday,
        range: DigestRange.today,
      );
      expect(text, contains(EntryKind.task.label));
      expect(text, contains(EntryKind.event.label));
    });
  });

  group('DigestRange', () {
    test('모르는 값은 오늘로 폴백한다', () {
      expect(DigestRange.fromValue(null), DigestRange.today);
      expect(DigestRange.fromValue('없는값'), DigestRange.today);
    });

    test('dbValue로 되찾을 수 있다', () {
      for (final r in DigestRange.values) {
        expect(DigestRange.fromValue(r.dbValue), r);
      }
    });
  });
}
