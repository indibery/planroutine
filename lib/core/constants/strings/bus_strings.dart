/// 버스 도착 카드 문자열.
class BusStrings {
  BusStrings._();

  // ── 설정 섹션 ──────────────────────────────────────────────
  static const section = '버스 도착';
  static const sectionDescription = '오늘 탭 맨 위에 출퇴근 버스 도착시간을 보여줍니다';
  static const showTitle = '표시';
  static const showSubtitleOn = '지정한 시간대에만 펼쳐집니다';
  static const showSubtitleOff = '꺼져 있어 오늘 탭이 지금과 같습니다';
  static const slotDeparture = '출발지';
  static const slotDepartureHint = '집 근처에서 타는 정류장';
  static const slotArrival = '도착지';
  static const slotArrivalHint = '학교 근처에서 타는 정류장';
  static const slotEmpty = '정류장 선택';
  static const cardStyle = '카드 모양';
  static const cardStyleHint = '도착시간을 어떻게 보여줄지';
  static const rangeToWork = '출근 시간대';
  static const rangeToHome = '퇴근 시간대';
  static const rangeHintToWork = '이 시간에만 출근 버스가 펼쳐집니다';
  static const rangeHintToHome = '이 시간에만 퇴근 버스가 펼쳐집니다';
  static const rangeOverlap = '출근과 퇴근 시간대가 겹칩니다';
  static const rangeInverted = '시작이 종료보다 빠르게 두세요';

  // ── 카드 ───────────────────────────────────────────────────
  static const routeToWork = '🏠→🏫 출근';
  static const routeToHome = '🏫→🏠 퇴근';
  static const seeToWork = '출근 보기';
  static const seeToHome = '퇴근 보기';
  static const collapse = '접기';
  static const expand = '펼치기';

  /// "07:32 기준" — 캐시 신선도를 감추지 않고 고백한다.
  static String basedOn(String hhmm) => '$hhmm 기준';

  /// 갱신에 실패해 캐시된 값을 보여줄 때.
  static String basedOnStale(String hhmm) => '$hhmm 기준 · 갱신 실패';

  /// "3개 더" — 필터를 걸지 않아 3개로 자른 뒤 남은 수.
  static String moreCount(int n) => '$n개 더';

  static String minutes(int n) => '$n분';
  static const arrivingNow = '곧 도착';
  static const lowFloor = '저상';

  /// 시간 축의 0분 눈금. 나머지 눈금은 `minutes(axisRange…)`로 파생된다.
  static const axisNow = '지금';

  // ── 실패 계약 5상태 (§3) ───────────────────────────────────
  /// 조회 전에만 쓰인다 — 조회 후 빈 목록은 buildBusCardView가 closed로 바꾼다.
  static const emptyLoading = '도착시간을 확인하고 있어요';
  static const emptyClosed = '오늘 운행이 끝났어요';

  /// 정류장에는 버스가 오는데 골라둔 노선만 지금 안 올 때. **막차 종료와 다른 말이어야
  /// 한다** — 기다릴지 다른 수단을 찾을지가 갈린다.
  static const emptyFiltered = '고른 노선은 지금 오지 않아요';
  static const emptyFilteredHint = '이 정류장에 오는 다른 버스는 설정에서 고를 수 있어요';
  static const emptyDown = '지금 정보를 못 받았어요';
  static const emptyDownAction = '다시 시도';
  static const emptyKey = '버스 정보를 불러올 수 없어요';
  static const emptyKeyHint = '잠시 뒤 다시 열어주세요';
  static const emptyNoStop = '정류장을 등록하면 도착시간이 보여요';
  static const emptyNoStopAction = '정류장 등록';

  // ── 검색 화면 ──────────────────────────────────────────────
  static const searchTitle = '정류장 찾기';
  static const cityLabel = '도시';
  static const citySearchHint = '시·군 이름 (예: 수원)';
  static const stopSearchHint = '정류장 이름 (예: 시청)';
  static const searchEmpty = '검색 결과가 없어요';
  static const searchPrompt = '정류장 이름을 입력해 주세요';

  /// 도시를 고르기 전에 검색을 누른 사람에게. **`searchPrompt`를 쓰면 안 된다** —
  /// 방금 이름을 넣은 사용자에게 이름을 넣으라고 말하는 셈이 된다.
  static const cityFirst = '먼저 도시를 골라주세요';

  // ── 확인 시트 (§4) ─────────────────────────────────────────
  static const confirmTitle = '이 정류장이 맞나요?';
  static const confirmRoutesTitle = '타는 버스만 남겨주세요';
  static const confirmNoRoutes = '지금 이 정류장에 오는 버스가 없어요';
  static const confirmReject = '아니에요';
  static const confirmAccept = '맞아요';
  static const confirmNeedRoute = '버스를 하나 이상 남겨주세요';
}
