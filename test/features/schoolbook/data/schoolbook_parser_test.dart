import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/schoolbook/data/schoolbook_parser.dart';

import '../fixture.dart';

void main() {
  test('login — 학교 이름과 교시 수', () {
    final info = parseLogin(loadSchoolbookFixture('login').body);
    expect(info.name, '플랜테스트');
    expect(info.periodCount, 7);
  });

  test('rooms — 이름과 정원', () {
    final rooms = parseRooms(loadSchoolbookFixture('rooms').body);
    expect(rooms.map((r) => r.name), contains('과학실'));
    expect(rooms.firstWhere((r) => r.name == '과학실').capacity, 2);
  });

  test('체육관 하루 — 고정 예약과 시각 없는 교시', () {
    final day = parseRoomDay(loadSchoolbookFixture('day_gym').body);
    expect(day.date, DateTime(2026, 10, 20));
    final first = day.periods.first;
    expect(first.name, '1교시');
    expect(first.fixed, ['3-2']);
    expect(first.startTime, '09:00');
    final afterSchool = day.periods.firstWhere((p) => p.name == '방과후');
    expect(afterSchool.startTime, isNull);
    expect(afterSchool.endTime, isNull);
  });

  test('과학실 하루 — 설정 때문에 취소된 예약은 canceled', () {
    final day = parseRoomDay(loadSchoolbookFixture('day_science').body);
    final fourth = day.periods.firstWhere((p) => p.name == '4교시');
    final canceled = fourth.bookings.firstWhere((b) => b.booker == '4-2');
    expect(canceled.canceled, isTrue);
    expect(fourth.bookings.firstWhere((b) => b.booker == '4-1').canceled, isFalse);
  });

  test('오류 응답의 detail을 그대로 읽는다', () {
    expect(parseDetail(loadSchoolbookFixture('book_full').body),
        '3교시의 남은 자리가 없습니다.');
    expect(parseDetail(null), isNull);
  });

  test('HTML 같은 엉뚱한 본문은 FormatException', () {
    expect(() => parseRooms('<html>'), throwsFormatException);
    expect(() => parseRoomDay({'date': 3}), throwsFormatException);
  });
}
