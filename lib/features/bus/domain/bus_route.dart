import 'bus_arrival.dart';

/// 정류장을 지나는 노선 1건 — **도착 여부와 무관한 노선 목록**이다.
///
/// [BusArrival]과 나누는 이유가 시간 무관성이다. 도착정보는 "지금 오는 버스"라서
/// 심야·배차 공백에는 비고(GBIS `resultCode: 4`), 그걸 선택 목록으로 쓰면 등록하는
/// **시각**이 고를 수 있는 노선을 결정한다 — 군포 장미아파트에서 10개 중 2개만
/// 고를 수 있었던 실기기 버그가 정확히 이것이었다(실측: 도착시각 있는 행 8/10,
/// 사용자 화면 2개).
///
/// DB에 저장되지 않는 조회 결과이므로 freezed 없이 plain class로 둔다
/// ([BusArrival]·`TodayView`와 같은 계열).
class BusRoute {
  const BusRoute({
    required this.routeId,
    required this.routeNo,
    required this.destName,
  });

  /// 노선 고유 ID. **`BusStop.routeIds`와 같은 문자열 공간이어야 한다** — 파서가
  /// `gbisIdPrefix`를 되붙이는 이유이고, 이 값이 곧 사용자가 저장하는 필터다.
  final String routeId;

  /// 화면에 보이는 노선번호. GBIS는 int와 String을 섞어 주므로 파서가 문자열로 받는다.
  final String routeNo;

  /// 행선지(종점). **이 시트에서 방향을 가르는 유일한 비중복 단서다.**
  ///
  /// 길 양쪽 정류장은 이름도 노선번호도 같지만 행선지는 다르다(실측 장미아파트:
  /// `3030 → 신사역(중)`, `6 → 금정역`). 노선번호만으로는 "내가 타는 버스가 여기
  /// 온다"까지만 알 수 있고 "어느 쪽으로 가는 정류장인지"는 알 수 없다.
  ///
  /// 도착정보 폴백 경로(비경기 정류장)에서는 빈 문자열이다 — TAGO 도착 응답에
  /// 행선지가 없다.
  final String destName;

  @override
  String toString() => 'BusRoute($routeNo → $destName)';
}

/// 확인 시트의 선택 항목 1건 — 노선 + (있으면) 지금 오는 버스의 남은 분.
class BusRouteChoice {
  const BusRouteChoice({required this.route, this.arrMin});

  final BusRoute route;

  /// 지금 오는 버스가 있으면 남은 분, 없으면 null.
  ///
  /// **0과 null이 다르다.** 0은 `곧 도착`이고 null은 `도착 정보가 없다`다 — 뭉개면
  /// 심야에 등록하는 사용자에게 모든 노선이 `곧 도착`으로 보인다.
  final int? arrMin;

  String get routeId => route.routeId;
}

/// 경유노선 + 도착정보 → 확인 시트에 그릴 선택 목록. **순수 함수다.**
///
/// [routes]가 비면 [arrivals]로 목록을 만든다 — 비경기 정류장(부산 `BSB…`·제주
/// `JEB…`)은 경유노선 API가 없고, 경기 정류장이라도 경유노선 조회가 실패할 수 있다.
/// 폴백에서는 행선지가 없으니 기존(도착정보 기반) 동작으로 정확히 되돌아간다.
///
/// 두 파서 모두 노선당 1건으로 축약해 주므로(`parseArrivals`의 fastest 맵,
/// `parseGbisArrivals`는 응답 자체가 1행) 여기서 중복을 다시 다루지 않는다.
List<BusRouteChoice> buildRouteChoices({
  required List<BusRoute> routes,
  required List<BusArrival> arrivals,
}) {
  final arrMinById = {for (final a in arrivals) a.routeId: a.arrMin};

  final base = routes.isNotEmpty
      ? routes
      : arrivals
          .map((a) => BusRoute(
                routeId: a.routeId,
                routeNo: a.routeNo,
                destName: '',
              ))
          .toList();

  return base
      .map((r) => BusRouteChoice(route: r, arrMin: arrMinById[r.routeId]))
      .toList()
    ..sort((x, y) => compareRouteNo(x.route.routeNo, y.route.routeNo));
}

/// 노선번호 자연순 — `6 · 9 · 11-5 · 15 · 87 · 541 · 917 · 3030 · 5623 · 6501`.
///
/// **정렬을 파서가 아니라 여기서 하는 이유**: 같은 응답을 카드는 빠른 순으로,
/// 시트는 번호순으로 쓴다. 카드는 "다음 버스가 언제"를 묻고 시트는 "내 번호가
/// 어디 있나"를 묻는다.
///
/// 사전순으로만 두면 `11-5`가 `6`보다 앞에 오고 `3030`이 맨 위에 온다 — 10개짜리
/// 목록에서 자기 번호를 훑어 찾지 못하는 것이 원래 버그의 감각이라 그대로 두면
/// 목록만 길어지고 찾기는 그대로다.
int compareRouteNo(String a, String b) {
  final na = _leadingInt(a);
  final nb = _leadingInt(b);

  // 숫자로 시작하지 않는 노선(마을버스 `A`·`가` 등)은 뒤로 모은다.
  if (na == null && nb != null) return 1;
  if (na != null && nb == null) return -1;
  if (na != null && nb != null && na != nb) return na.compareTo(nb);

  // 같은 수로 시작하면 사전순 — `11` 다음 `11-5`.
  return a.compareTo(b);
}

final _leadingDigits = RegExp(r'^\d+');

int? _leadingInt(String s) => int.tryParse(_leadingDigits.stringMatch(s) ?? '');
