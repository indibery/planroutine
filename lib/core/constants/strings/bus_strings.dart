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
  /// 카드 제목줄의 방향 표시 — **이모지와 글자를 나눠 둔다.**
  ///
  /// 카드가 `Text.rich`의 두 span으로 그려 **이모지만 조금 크게** 한다. 한 문자열이면
  /// 이모지가 글자와 같은 13px에 묶여 작게 보이는데, 집·학교를 한눈에 구별하는 것이
  /// 이 라벨의 일이다(사용자 요청, 2026-07-29).
  static const emojiToWork = '🏠→🏫';
  static const emojiToHome = '🏫→🏠';
  static const titleToWork = '출근';
  static const titleToHome = '퇴근';

  /// 제목줄 이모지 크기. 글자는 13px이다.
  ///
  /// 상수로 두는 이유는 폭 측정과 묶여 있기 때문이다 — 이 값을 키우면 제목줄이 넓어지고
  /// 좁은 화면에서 정류장 이름이 밀린다. `test/tools/visual_check.dart`가 실측 폰트로
  /// 폭을 잰다(폴백 폰트로 재면 1.76배 부풀어 결론이 뒤집힌다).
  static const headerEmojiSize = 16.0;

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

  /// 제목줄 새로고침 아이콘의 스크린리더 라벨. 글자가 없으므로 이것이 유일한 이름이다.
  static const refresh = '새로고침';

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
  /// **번호를 먼저 말한다.** 이름만으로는 결과가 감당이 안 된다(실측 `시청` 160곳,
  /// `아파트` 4,366곳). 정류소번호는 정류장 표지판과 지도 앱에 적혀 있고 한 번에
  /// 한 곳으로 좁혀진다(실측 `26044` → 1곳).
  static const stopSearchHint = '정류소번호 또는 이름 (예: 26044)';
  static const searchEmpty = '검색 결과가 없어요';
  static const searchPrompt = '정류소번호나 정류장 이름을 넣어주세요';

  /// GBIS가 1글자를 거부한다(`resultCode 22`). **응답 메시지는 `1자리 이상`이라고
  /// 하는데 1자리도 거부한다** — 실제 규칙은 2자리 이상이다. 화면이 먼저 막으므로
  /// 헛요청이 나가지 않는다.
  static const searchTooShort = '두 글자 이상 넣어주세요';

  /// 결과가 상한을 넘었을 때. 지역 칩과 함께 뜬다.
  ///
  /// 건수를 밝히는 이유: `검색 결과가 없어요`도 아니고 목록이 잘린 것도 아닌,
  /// **너무 많아서 좁혀야 하는** 상황이라는 것이 숫자 없이는 전달되지 않는다.
  static String searchTooMany(int total) => '$total곳이 찾아졌어요';

  /// 그 아래 붙는 해결책. 지역 칩이 바로 위에 있으므로 둘을 함께 말한다.
  static const searchTooManyHint = '지역을 고르거나, 정류소번호를 넣으면 한 곳만 나와요';

  /// "군포 3" — 검색 결과에서 뽑은 지역 칩.
  ///
  /// 도시 목록(TAGO 138개)과 무관하다 — **지금 결과에 실제로 있는 지역만** 칩이 되고
  /// 추가 조회도 없다. 건수를 붙이는 이유는 어느 칩이 내 정류장을 담고 있을지
  /// 짐작하게 하는 것이다.
  static String regionChip(String region, int count) => '$region $count';

  /// 지역 필터를 해제하는 칩.
  static const regionAll = '전체';

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

  /// 검색 전 안내. 도시를 고르지 않아도 되는 범위를 미리 말한다 — 안 말하면
  /// 수도권 밖 사용자가 이름만 여러 번 고쳐 넣으며 헛수고한다.
  static const searchCapitalHint =
      '서울·경기·인천은 도시를 고르지 않아도 찾아요\n정류소번호로 찾으면 한 곳만 나옵니다';

  /// 도시 선택을 펼치는 링크.
  static const searchOtherRegion = '다른 지역에서 찾기';

  /// 그 링크 위에 붙는 이유.
  static const searchOtherRegionHint = '서울·경기·인천이 아니면 도시를 골라주세요';

  /// "군포 · 26044" — 검색 결과 행의 부제.
  ///
  /// **지역명이 여기 있어야 한다.** 도시를 먼저 고르지 않는 경로에서는 화면 어디에도
  /// 지역 정보가 없는데, 같은 이름의 정류장이 여러 시·군에 있다(실측 `장미아파트` →
  /// 의왕·인천·군포·시흥). 도시 선택 단계가 조용히 제공하던 정보를 행으로 옮긴 것이다.
  static String stopRegion(String region, int nodeNo) => '$region · $nodeNo';

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

  /// 서울 정류장을 고를 때. **목록이 전부가 아님을 밝힌다.**
  ///
  /// 서울은 경기버스정보에서 조회하는데 거기에는 경기를 지나는 노선만 담겨 있다
  /// (실측 응암역: 1개만 나온다). 사용자가 목록을 전부라고 믿고 등록하면, 자기 버스가
  /// 영구히 안 보이는데 이유를 알 수 없다. 시트는 노선 전체를 보여주므로 여기서
  /// 알리면 사용자가 자기 버스가 있는지 보고 판단할 수 있다.
  ///
  /// 서울 전용 API가 붙으면 이 문구는 없어진다.
  static const confirmSeoulPartial = '서울 정류장은 아직 일부 노선만 보여요';
  static const confirmReject = '아니에요';
  static const confirmAccept = '맞아요';
  static const confirmNeedRoute = '버스를 하나 이상 남겨주세요';
}
