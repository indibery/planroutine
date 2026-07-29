/// 버스 도착 카드 문자열.
class BusStrings {
  BusStrings._();

  // ── 카드 모양 이름 (BusCardStyle) ─────────────────────────
  /// `SealStyle`이 `TodayStrings`를 참조하는 것과 같은 형태다 — enum에 한글을 박으면
  /// 문구를 찾을 때 도메인까지 훑어야 한다.
  static const styleText = '간단히';
  static const styleAxis = '시간 축';

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

  /// "720번" — 노선번호에 붙는 조사. **카드와 확인 시트가 같은 함수를 쓴다.**
  ///
  /// 인라인으로 두면 표기를 손볼 때 한쪽만 따라간다(`시간 축`은 폭이 없어 번을
  /// 붙이지 않으므로 이 함수를 쓰지 않는다 — 의도된 예외다).
  static String routeLabel(String routeNo) => '$routeNo번';

  /// "· 수원시청" — 제목줄에서 방향 이름 뒤에 붙는 정류장 세그먼트.
  static String stopSegment(String stopName) => '· $stopName';

  /// "퇴근 보기 ⌄" — 반대 방향으로 넘어가는 링크. 글리프를 문구와 함께 든다.
  static String flip(String otherLabel) => '$otherLabel ⌄';

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

  /// "2분 후" — 확인 시트처럼 도착 시각을 **문장으로** 말하는 자리에서만 쓴다.
  ///
  /// 카드는 좁아서 [minutes]만 쓴다. 두 표기가 갈라져 있던 것이 아니라 같은 값을
  /// 두 방식으로 조립하고 있었으므로, `후`를 붙이는 규칙도 여기 한 곳에 둔다.
  static String minutesLater(int n) => '${minutes(n)} 후';

  static const arrivingNow = '곧 도착';

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

  /// `다시 시도`가 비행 중일 때 같은 자리에 놓는 진행 문구.
  ///
  /// 없으면 탭한 뒤 최대 10초(타임아웃) 동안 화면이 **전혀** 바뀌지 않는다 —
  /// 실패는 캐시되지 않으므로 사용자가 다시 누르는 만큼 동시 요청이 늘어난다.
  /// 키는 IPA에 하나뿐이라 개발계정 10,000/일 한도를 전 사용자가 공유한다.
  static const emptyDownRetrying = '다시 확인하고 있어요';
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

  /// "출발지 정류장 찾기" — 어느 슬롯을 채우는지 제목이 말한다.
  ///
  /// 카드에서 들어오면 슬롯이 **시계로 자동 결정**된다(기본 시간대에서 08:31–15:59는
  /// 도착지). 제목이 말해주지 않으면 사용자는 출발지를 고른다고 믿고 도착지를
  /// 덮어쓴다 — 설정 탭 경로에서는 아는 것을 카드 경로에서는 알 방법이 없었다.
  ///
  /// 조립해 쓴다: 슬롯 이름을 여기 다시 박으면 용어를 바꿀 때 타일만 따라가고
  /// 이 제목만 옛 이름으로 남는다.
  static String searchTitleFor(String slot) => '$slot $searchTitle';

  /// "출발지에 저장합니다" — 확인 시트가 저장 대상을 밝힌다.
  static String savesTo(String slot) => '$slot에 저장합니다';

  // ── 확인 시트 (§4) ─────────────────────────────────────────
  static const confirmTitle = '이 정류장이 맞나요?';
  static const confirmRoutesTitle = '타는 버스만 남겨주세요';
  static const confirmNoRoutes = '지금 이 정류장에 오는 버스가 없어요';

  /// "신사역(중) 방면" — 확인 시트에서 노선번호 아래 붙는 행선지.
  ///
  /// 길 양쪽 정류장은 이름도 노선번호도 같고 **행선지만 다르다.** 이 시트가 방향을
  /// 확인시키는 화면이므로, 사용자가 실제로 판단에 쓰는 문자열이 이것이다.
  static String routeDest(String dest) => '$dest 방면';

  /// 경유노선은 받았지만 도착 시간을 못 받았을 때. 목록과 행선지는 그대로 쓸 수
  /// 있으니 저장을 막지 않고 이유만 밝힌다 — 시간이 통째로 빈 목록에 설명이 없으면
  /// 목록이 깨진 것으로 읽힌다.
  static const confirmNoArrivalTimes = '도착 시간은 지금 못 받았어요';
  static const confirmReject = '아니에요';
  static const confirmAccept = '맞아요';
  static const confirmNeedRoute = '버스를 하나 이상 남겨주세요';
}
