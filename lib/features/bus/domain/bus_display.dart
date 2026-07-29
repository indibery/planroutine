import 'bus_settings.dart';
import 'commute_direction.dart';

/// 시간대 밖에서 사용자가 펼친 뒤 유지되는 시간.
///
/// 30분인 이유: 기본 출근 시간대 종료(08:30) + 30분 = 09:00으로, 일과시간이
/// 시작될 때 자동으로 접힌다. 별도 `일과시간` 설정을 두면 사용자가 출근 시간대를
/// 바꿨을 때 어긋나므로 시간대에서 파생시킨다.
const expandOverrideLifetime = Duration(minutes: 30);

/// 카드가 지금 어느 방향을 어떤 상태로 보여야 하는지.
class BusDisplay {
  const BusDisplay({required this.direction, required this.expanded});

  final CommuteDirection direction;

  /// 펼쳐져 있는지. **false면 TAGO 요청을 보내지 않는다**(스펙 §6 조건 3).
  final bool expanded;
}

/// 시간대와 override로 방향·펼침을 정한다. **순수 함수.**
///
/// 접기와 펼치기의 수명이 다르다 — 겉보기에 같은 토글이지만 뜻이 다르다.
/// 시간대 안에서 접기는 "오늘 아침 볼일 끝"이라 그 시간대가 끝날 때까지 살고,
/// 시간대 밖에서 펼치기는 "지금 잠깐 예외로 필요"라 30분만 산다. 같은 수명을
/// 주면 둘 중 하나가 반드시 틀린다.
BusDisplay resolveBusDisplay({
  required DateTime now,
  required BusSettings settings,
}) {
  // 시간대가 겹치거나 뒤집혔으면 방향 판정이 모호하다. 접힌 채로 두면 요청도
  // 나가지 않아 안전하다(설정 화면이 저장을 막지만 옛 저장값이 있을 수 있다).
  //
  // **이 폴백은 순수 함수의 마지막 방어선일 뿐 사용자가 보는 상태가 아니다** —
  // override보다 먼저 반환하므로 이 상태로 살아 있으면 제목줄 탭이 영구 no-op가
  // 된다. 그래서 `BusSettingsNotifier.build`가 읽는 순간 시간대를 기본값으로
  // 되돌려 저장해 이 분기에 머무르지 않게 한다.
  if (!settings.rangesValid) {
    return const BusDisplay(
      direction: CommuteDirection.toWork,
      expanded: false,
    );
  }

  final inToWork = settings.toWorkRange.contains(now);
  final inToHome = settings.toHomeRange.contains(now);

  final CommuteDirection direction;
  final bool byRange;
  if (inToWork) {
    direction = CommuteDirection.toWork;
    byRange = true;
  } else if (inToHome) {
    direction = CommuteDirection.toHome;
    byRange = true;
  } else {
    // 다음에 올 시간대의 방향 — 밤 9시에 보여줄 것은 내일 출근 버스이고
    // 오전 10시에 보여줄 것은 오늘 퇴근 버스다.
    direction = _nextDirection(now, settings);
    byRange = false;
  }

  final override = _overrideValue(now: now, settings: settings, byRange: byRange);
  return BusDisplay(direction: direction, expanded: override ?? byRange);
}

/// 시간대 밖일 때, 시간 순으로 다음에 열릴 시간대의 방향.
CommuteDirection _nextDirection(DateTime now, BusSettings settings) {
  final minutes = now.hour * 60 + now.minute;
  if (minutes < settings.toWorkRange.startMinutes) {
    return CommuteDirection.toWork;
  }
  if (minutes < settings.toHomeRange.startMinutes) {
    return CommuteDirection.toHome;
  }
  // 퇴근 시간대까지 지났으면 다음은 내일 출근이다.
  return CommuteDirection.toWork;
}

/// 아직 유효한 override의 값. 없거나 만료면 null.
bool? _overrideValue({
  required DateTime now,
  required BusSettings settings,
  required bool byRange,
}) {
  final at = settings.overrideAt;
  if (at == null) return null;
  if (at.isAfter(now)) return null; // 기기 시계가 뒤로 갔다 — 무시한다

  if (settings.overrideExpanded) {
    // 펼치기 — 30분.
    return now.difference(at) < expandOverrideLifetime
        ? true
        : null;
  }

  // 접기 — 누른 그 시간대가 끝날 때까지. 같은 날이면서, 누른 시각과 지금이
  // 같은 시간대 안에 있어야 한다.
  if (!_sameDay(at, now) || !byRange) return null;
  final range = settings.toWorkRange.contains(at)
      ? settings.toWorkRange
      : settings.toHomeRange;
  return range.contains(at) && range.contains(now) ? false : null;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
