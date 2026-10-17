import 'schoolbook_models.dart';

/// 교시 줄에 보이는 사람 하나. 고정 반이거나 날짜 예약이다.
class PersonChip {
  const PersonChip({
    required this.label,
    required this.fixed,
    this.bookingId,
    required this.cancellable,
    this.mine = false,
  });

  final String label;
  final bool fixed;
  final int? bookingId;

  /// 내 예약(저장한 예약자 이름과 같은 날짜 예약)이고 지난 날이 아니다.
  final bool cancellable;

  /// 저장한 예약자 이름과 같은 날짜 예약 — 화면이 강조한다.
  final bool mine;
}

/// 교시 줄 끝 버튼 자리 하나에 무엇을 둘까(시안 A).
enum RowAction { book, cancel, none }

/// 교시 한 줄을 그리는 데 필요한 판정.
class PeriodRowView {
  const PeriodRowView({
    required this.slot,
    required this.people,
    required this.selectable,
    required this.remainingToShow,
    required this.action,
    this.myBooking,
  });

  final PeriodSlot slot;
  final List<PersonChip> people;

  /// 체크해서 예약할 수 있는가.
  final bool selectable;

  /// `n자리 남음`의 n. 정원 1이거나 다 찼으면 null(적지 않는다).
  final int? remainingToShow;

  /// 내 예약이 있으면 취소가 먼저다 — 같은 반이 같은 교시를 두 번 잡을 일은 없다.
  final RowAction action;

  /// 이 교시의 내 예약(취소 버튼이 지울 것).
  final PersonChip? myBooking;
}

/// 한 교시 줄의 판정. 취소된 예약은 빈자리에서 빠지는 행이라 보이지 않는다
/// — 보이면 "누가 있는데 비었다"로 읽힌다.
PeriodRowView buildPeriodRow(
  PeriodSlot slot, {
  required int capacity,
  required bool bookableDay,
  required bool pastDay,
  String? myBooker,
}) {
  final me = myBooker?.trim();
  bool isMine(SlotBooking b) => me != null && me.isNotEmpty && b.booker.trim() == me;
  final people = [
    for (final booker in slot.fixed)
      PersonChip(label: booker, fixed: true, cancellable: false),
    for (final b in slot.bookings)
      if (!b.canceled)
        PersonChip(
          label: b.booker,
          fixed: false,
          bookingId: b.id,
          cancellable: isMine(b) && !pastDay,
          mine: isMine(b),
        ),
  ];
  final selectable = bookableDay && !slot.archived && slot.remaining > 0;
  final myBooking = [for (final p in people) if (p.cancellable) p].firstOrNull;
  return PeriodRowView(
    slot: slot,
    people: people,
    selectable: selectable,
    remainingToShow:
        capacity > 1 && slot.remaining > 0 ? slot.remaining : null,
    action: myBooking != null
        ? RowAction.cancel
        : selectable
            ? RowAction.book
            : RowAction.none,
    myBooking: myBooking,
  );
}
