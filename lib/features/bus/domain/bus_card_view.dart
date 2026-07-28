import 'bus_arrival.dart';

/// 3분 미만이면 임박. 두 모양 모두 이 값으로 강조를 정한다.
const busUrgentMinutes = 3;

/// 3~7분 구간. `시간 축`의 가운데 색이 여기다.
const busSoonMinutes = 7;

/// 노선 필터를 걸지 않았을 때 보여주는 최대 개수.
///
/// 월 그리드가 이벤트 점을 3개로 자르는 것과 같은 값이다.
const busUnfilteredLimit = 3;

bool isUrgent(int arrMin) => arrMin < busUrgentMinutes;

bool isSoon(int arrMin) => arrMin >= busUrgentMinutes && arrMin <= busSoonMinutes;

/// 카드가 그릴 상태 — 스펙 §3의 실패 계약 5상태 + 슬롯 미설정.
enum BusCardState {
  ok,

  /// 갱신에 실패했지만 캐시된 목록은 있다. 목록 + "07:30 기준 · 갱신 실패".
  stale,

  /// 오는 버스가 없다. 막차 후이거나 고른 노선이 지금 안 온다.
  closed,

  /// 조회 실패 + 캐시 없음.
  down,

  /// 인증키 문제. 사용자에게 키 이야기를 하지 않는다.
  keyError,

  /// 정류장 슬롯이 비었다. 등록 유도를 띄운다(무한 로딩 금지).
  noStop,
}

/// 카드가 그릴 것 전부 — [buildBusCardView]의 출력.
class BusCardView {
  const BusCardView({
    required this.state,
    required this.visible,
    required this.hiddenCount,
    required this.fetchedAt,
  });

  final BusCardState state;

  /// 화면에 그릴 목록. 보정·필터·정렬·상한이 모두 적용된 결과.
  final List<BusArrival> visible;

  /// 상한 때문에 감춘 개수. 0이면 `N개 더`를 그리지 않는다.
  final int hiddenCount;

  /// 마지막 조회 시각. `07:32 기준` 문구의 근거이고 null이면 감춘다.
  final DateTime? fetchedAt;

  bool get hasRows => visible.isNotEmpty;
}

/// 조회 결과를 화면 상태로 바꾼다. **순수 함수.**
///
/// 계산 순서가 중요하다 — 경과 보정 → 노선 필터 → 정렬 → 상한. 보정을 나중에
/// 하면 상한이 옛 순서로 잘려 방금 지나간 버스가 목록에 남는다.
BusCardView buildBusCardView({
  required BusCardState state,
  required List<BusArrival> arrivals,
  required DateTime? fetchedAt,
  required DateTime now,
  Set<String> routeIds = const {},
}) {
  // 1) 경과 보정 — 캐시가 묵은 만큼 차감한다. 서버가 "4분"이라고 준 값이 50초
  //    묵었으면 화면에는 3분으로 나가야 한다.
  //
  //    round를 쓰는 이유: floor는 조회 1초 뒤에 239초를 3분으로 떨어뜨려 표시가
  //    튄다. ceil은 반대로 최대 59초를 과대 표시해 사용자가 버스를 놓칠 수 있다.
  final elapsed = fetchedAt == null ? 0 : now.difference(fetchedAt).inSeconds;
  final adjusted = arrivals.map((a) {
    if (elapsed <= 0) return a;
    final remaining = a.arrMin * 60 - elapsed;
    return a.copyWith(arrMin: remaining <= 0 ? 0 : (remaining / 60).round());
  });

  // 2) 노선 필터 — 비어 있으면 "필터 없음"이라 전부 통과한다.
  final filtered = routeIds.isEmpty
      ? adjusted.toList()
      : adjusted.where((a) => routeIds.contains(a.routeId)).toList();

  // 3) 정렬 — 보정으로 순서가 바뀔 수 있다.
  filtered.sort((a, b) => a.arrMin.compareTo(b.arrMin));

  // 4) 상한 — 필터를 걸었다면 자르지 않는다. 자기가 고른 것을 감추면 안 된다.
  final limited = routeIds.isEmpty && filtered.length > busUnfilteredLimit
      ? filtered.sublist(0, busUnfilteredLimit)
      : filtered;
  final hidden = filtered.length - limited.length;

  // 빈 목록은 closed로 바꾼다. 다만 장애·키 오류는 막차와 구별해야 하므로
  // 그대로 남긴다 — 정류장에서 기다릴지 택시를 부를지가 갈린다.
  final resolved = limited.isEmpty && state == BusCardState.ok
      ? BusCardState.closed
      : state;

  return BusCardView(
    state: resolved,
    visible: limited,
    hiddenCount: hidden,
    fetchedAt: fetchedAt,
  );
}
