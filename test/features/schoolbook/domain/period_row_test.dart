import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/schoolbook/domain/period_row.dart';
import 'package:planroutine/features/schoolbook/domain/schoolbook_models.dart';

PeriodSlot _slot({
  int remaining = 1,
  bool archived = false,
  List<String> fixed = const [],
  List<SlotBooking> bookings = const [],
}) =>
    PeriodSlot(
      id: 1,
      name: '3교시',
      archived: archived,
      remaining: remaining,
      fixed: fixed,
      bookings: bookings,
    );

PeriodRowView _row(
  PeriodSlot slot, {
  int capacity = 1,
  bool bookableDay = true,
  bool pastDay = false,
}) =>
    buildPeriodRow(slot,
        capacity: capacity, bookableDay: bookableDay, pastDay: pastDay);

void main() {
  test('취소된 예약은 사람 목록에 없다', () {
    final view = _row(_slot(bookings: const [
      SlotBooking(id: 1, booker: '4-1', canceled: false),
      SlotBooking(id: 2, booker: '4-2', canceled: true),
    ]));
    expect(view.people.map((p) => p.label), ['4-1']);
  });

  test('고정은 취소할 수 없고 날짜 예약은 번호를 든다', () {
    final view = _row(_slot(
      remaining: 0,
      fixed: const ['3-2'],
      bookings: const [SlotBooking(id: 9, booker: '5-1', canceled: false)],
    ), capacity: 2);
    final fixed = view.people.first;
    expect(fixed.fixed, isTrue);
    expect(fixed.cancellable, isFalse);
    expect(fixed.bookingId, isNull);
    final booked = view.people.last;
    expect(booked.bookingId, 9);
    expect(booked.cancellable, isTrue);
  });

  test('지난 날은 체크도 취소도 안 된다', () {
    final view = _row(
      _slot(bookings: const [SlotBooking(id: 9, booker: '5-1', canceled: false)]),
      capacity: 2,
      bookableDay: false,
      pastDay: true,
    );
    expect(view.selectable, isFalse);
    expect(view.people.single.cancellable, isFalse);
  });

  test('남은 자리가 없으면 체크할 수 없다', () {
    expect(_row(_slot(remaining: 0)).selectable, isFalse);
  });

  test('지운 교시는 체크할 수 없다', () {
    expect(_row(_slot(archived: true)).selectable, isFalse);
  });

  test('예약할 수 없는 날(주말 · 범위 밖)은 체크할 수 없다', () {
    expect(_row(_slot(), bookableDay: false).selectable, isFalse);
  });

  test('예약할 수 있으면 체크할 수 있다', () {
    expect(_row(_slot()).selectable, isTrue);
  });

  group('남은 자리 표기', () {
    test('정원 1이면 적지 않는다', () {
      expect(_row(_slot(remaining: 1)).remainingToShow, isNull);
    });
    test('정원 2에 1자리 남으면 1', () {
      expect(_row(_slot(remaining: 1), capacity: 2).remainingToShow, 1);
    });
    test('다 차면 적지 않는다', () {
      expect(_row(_slot(remaining: 0), capacity: 2).remainingToShow, isNull);
    });
  });
}
