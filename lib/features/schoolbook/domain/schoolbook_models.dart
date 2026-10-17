import 'package:freezed_annotation/freezed_annotation.dart';

part 'schoolbook_models.freezed.dart';

/// 스쿨북 학교 — 로그인 응답에서 쓰는 것만.
@freezed
abstract class SchoolInfo with _$SchoolInfo {
  const factory SchoolInfo({
    required String code,
    required String name,
    required int periodCount,
  }) = _SchoolInfo;
}

/// 교실(장소). `capacity` = 한 교시에 동시에 예약할 수 있는 반의 수.
@freezed
abstract class SchoolbookRoom with _$SchoolbookRoom {
  const factory SchoolbookRoom({
    required int id,
    required String name,
    required int capacity,
  }) = _SchoolbookRoom;
}

/// 날짜 예약 한 건. `canceled`는 설정 변경으로 취소 표시된 것이다(빈자리에서 빠진다).
@freezed
abstract class SlotBooking with _$SlotBooking {
  const factory SlotBooking({
    required int id,
    required String booker,
    required bool canceled,
  }) = _SlotBooking;
}

/// 하루 중 한 교시. `fixed`는 그날 고정 시간표의 반들이다.
@freezed
abstract class PeriodSlot with _$PeriodSlot {
  const factory PeriodSlot({
    required int id,
    required String name,
    String? startTime,
    String? endTime,
    required bool archived,
    required int remaining,
    required List<String> fixed,
    required List<SlotBooking> bookings,
  }) = _PeriodSlot;
}

/// 교실 하나의 하루 예약.
@freezed
abstract class RoomDay with _$RoomDay {
  const factory RoomDay({
    required DateTime date,
    required List<PeriodSlot> periods,
  }) = _RoomDay;
}
