import 'schoolbook_models.dart';

/// 교시 줄에 보이는 사람 하나. 고정 반이거나 날짜 예약이다.
class PersonChip {
  const PersonChip({
    required this.label,
    required this.fixed,
    this.bookingId,
    required this.cancellable,
  });

  final String label;
  final bool fixed;
  final int? bookingId;
  final bool cancellable;
}

/// 교시 한 줄을 그리는 데 필요한 판정.
class PeriodRowView {
  const PeriodRowView({
    required this.slot,
    required this.people,
    required this.selectable,
    required this.remainingToShow,
  });

  final PeriodSlot slot;
  final List<PersonChip> people;

  /// 체크해서 예약할 수 있는가.
  final bool selectable;

  /// `n자리 남음`의 n. 정원 1이거나 다 찼으면 null(적지 않는다).
  final int? remainingToShow;
}

/// 한 교시 줄의 판정. 취소된 예약은 빈자리에서 빠지는 행이라 보이지 않는다
/// — 보이면 "누가 있는데 비었다"로 읽힌다.
PeriodRowView buildPeriodRow(
  PeriodSlot slot, {
  required int capacity,
  required bool bookableDay,
  required bool pastDay,
}) {
  final people = [
    for (final booker in slot.fixed)
      PersonChip(label: booker, fixed: true, cancellable: false),
    for (final b in slot.bookings)
      if (!b.canceled)
        PersonChip(
          label: b.booker,
          fixed: false,
          bookingId: b.id,
          cancellable: !pastDay,
        ),
  ];
  return PeriodRowView(
    slot: slot,
    people: people,
    selectable: bookableDay && !slot.archived && slot.remaining > 0,
    remainingToShow:
        capacity > 1 && slot.remaining > 0 ? slot.remaining : null,
  );
}
