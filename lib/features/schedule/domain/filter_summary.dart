import '../../../core/constants/app_strings.dart';
import 'entry_kind.dart';
import 'schedule.dart';

/// 접힌 필터 줄에 쓰는 요약 문자열 — 순수 함수.
///
/// 필터를 접어도 **무엇으로 걸러진 상태인지**는 화면에 남아야 한다.
/// 그래서 상태(건수) 뒤에 켜진 필터만 가운뎃점으로 잇는다:
/// `검토 대기 21 · 업무 · 일과운영`.
///
/// [categoryLabel]은 이미 축약된 라벨을 받는다(`shortenCategory`는 presentation
/// 계층이라 도메인에서 부르지 않는다).
String buildFilterSummary({
  required ScheduleStatus? status,
  required EntryKind? kind,
  required String? categoryLabel,
  required int pendingCount,
  required int confirmedCount,
}) {
  final parts = <String>[
    switch (status) {
      ScheduleStatus.pending => ScheduleStrings.chipPending(pendingCount),
      ScheduleStatus.confirmed => ScheduleStrings.chipConfirmed(confirmedCount),
      null => '${ScheduleStrings.all} ${pendingCount + confirmedCount}',
    },
    if (kind != null) kind.filterLabel,
    if (categoryLabel != null && categoryLabel.isNotEmpty) categoryLabel,
  ];
  return parts.join(' · ');
}

/// 기본(전체)에서 좁혀진 필터가 걸려 있는지. 접힌 줄의 강조 여부에 쓴다.
bool hasNarrowingFilter({
  required EntryKind? kind,
  required String? categoryLabel,
}) {
  return kind != null || (categoryLabel != null && categoryLabel.isNotEmpty);
}
