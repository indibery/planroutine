import '../../../core/constants/app_strings.dart';
import 'entry_kind.dart';
import 'schedule.dart';

/// 접힌 필터 줄에 쓰는 요약 문자열 — 순수 함수.
///
/// 필터를 접어도 **무엇으로 걸러진 상태인지**는 화면에 남아야 한다.
/// 그래서 상태(건수) 뒤에 켜진 필터만 가운뎃점으로 잇는다:
/// `검토 대기 21 · 업무 · 일과운영`.
///
/// [visibleCount]는 **지금 목록에 보이는 건수**다 — 전역 건수를 쓰면 안 된다.
/// 종류·카테고리로 좁혀 목록이 비었는데 요약만 `검토 대기 21`이라고 말하면,
/// 사용자는 21건이 걸러져 있다고 읽는데 화면은 비어 있다. 상태 칩(펼친 줄)은
/// 전역 건수를 그대로 쓰지만 둘은 동시에 보이지 않는다(펼치면 요약을 감춘다).
///
/// [categoryLabel]은 이미 축약된 라벨을 받는다(`shortenCategory`는 presentation
/// 계층이라 도메인에서 부르지 않는다).
String buildFilterSummary({
  required ScheduleStatus? status,
  required EntryKind? kind,
  required String? categoryLabel,
  required int visibleCount,
}) {
  final statusPart = switch (status) {
    ScheduleStatus.pending => ScheduleStrings.chipPending(visibleCount),
    ScheduleStatus.confirmed => ScheduleStrings.chipConfirmed(visibleCount),
    null => '${ScheduleStrings.all} $visibleCount',
  };
  return [statusPart, ..._narrowingParts(kind, categoryLabel)].join(_separator);
}

/// 일괄 삭제 다이얼로그가 "무엇을 대상으로 하는지" 말할 때 쓰는 범위 이름.
///
/// 다이얼로그 문구와 실제 쿼리 범위가 어긋나면 되돌리기 어려운 삭제가 조용히
/// 커진다 — 그래서 둘 다 같은 두 필터(종류·카테고리)에서 나오게 묶어 둔다.
/// 아무 필터도 없으면 `전체`.
///
/// 일괄 **확정**은 이걸 쓰지 않는다 — 확정 pill의 종류는 필터가 아니라 pill 자신에서
/// 오므로 범위의 출처가 다르다(`kind.label`을 그대로 쓴다).
String buildScopeLabel({
  required EntryKind? kind,
  required String? categoryLabel,
}) {
  final parts = _narrowingParts(kind, categoryLabel);
  return parts.isEmpty ? ScheduleStrings.all : parts.join(_separator);
}

/// 기본(전체)에서 좁혀진 필터가 걸려 있는지. 접힌 줄의 강조 여부에 쓴다.
bool hasNarrowingFilter({
  required EntryKind? kind,
  required String? categoryLabel,
}) {
  return _narrowingParts(kind, categoryLabel).isNotEmpty;
}

const _separator = ' · ';

/// 켜진 좁힘 필터를 표시 순서대로. 위 셋이 "무엇이 걸려 있나"를 각자 유도하면
/// 필터가 하나 늘 때 세 곳을 고쳐야 하고, 그중 하나를 빠뜨려도 아무도 안 알려준다.
List<String> _narrowingParts(EntryKind? kind, String? categoryLabel) => [
  if (kind != null) kind.label,
  if (categoryLabel != null && categoryLabel.isNotEmpty) categoryLabel,
];
