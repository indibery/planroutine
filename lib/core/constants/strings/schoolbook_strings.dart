/// 장소 예약(스쿨북) 문자열.
class SchoolbookStrings {
  SchoolbookStrings._();

  static const tabLabel = '장소 예약';
  static const title = '장소 예약';
  static const eyebrow = 'SCHOOLBOOK';
  static const moduleDescription = '스쿨북 학교의 장소 예약을 하루씩 보고 예약·취소합니다';
  static const settingsShortcut = '장소 예약 설정';

  // 학교 연결
  static const connectTitle = '스쿨북 학교 링크를 붙여 넣어 주세요';
  static const connectHint = '스쿨북에서 쓰는 학교 주소를 복사해 오면 됩니다';
  static const connectFieldLabel = '학교 링크';
  static const connectButton = '연결';
  static const connectNotFound = '학교를 찾을 수 없어요. 링크를 확인해 주세요';
  static String connected(String school) => '$school에 연결했어요';
  static const summaryNotConnected = '학교를 연결해 주세요';

  // 스쿨북 안내 · 제작자 감사(호칭은 제작자가 사이트에서 쓰는 이름 — 사용자 결정 2026-10-23)
  static const maker = 'CODER 승쨩';
  static const intro =
      '스쿨북은 $maker 선생님이 만든 학교 장소·물품 예약 서비스예요. 아이디·비밀번호 없이 학교 링크 하나로 함께 씁니다.';
  static const openSite = '스쿨북 사이트 열기';
  static const joinPrompt = '우리 학교가 아직 스쿨북을 쓰지 않나요?';
  static const joinAction = '스쿨북에서 학교 가입하기';
  static const openWeb = '스쿨북 웹에서 열기';
  static const openWebHint = '교시·교실·물품 관리';
  static const openFailed = '사이트를 열지 못했어요';
  static const creditTitle = '함께 만든 서비스';
  static const creditSubtitle = '장소 예약 — 스쿨북 · $maker 선생님';
  static const creditService = '스쿨북 — 학교의 모든 예약';
  static const creditMaker = '만든 사람 · $maker 선생님';
  static const creditThanks =
      '공직플랜의 장소 예약은 스쿨북을 만든 $maker 선생님이 연결을 허락하고 도와주셔서 만들 수 있었습니다. 고맙습니다.';
  static const creditContact =
      '스쿨북 자체에 대한 문의·제보는 스쿨북 사이트로, 앱 사용 문의는 공직플랜으로 보내 주세요.';

  // 오류 · 빈 상태
  static const loadFailed = '불러오지 못했어요';
  static const retry = '다시 시도';
  static const disconnectedTitle = '학교 연결이 끊겼어요';
  static const reconnect = '다시 연결';
  static const noPeriods = '스쿨북에서 교시를 먼저 등록해 주세요';
  static const noRooms = '스쿨북에 등록된 장소가 없어요';
  static const noSlots = '이날은 예약할 수 있는 교시가 없어요';

  // 하루 보기
  static const previousWeek = '지난주';
  static const nextWeek = '다음 주';
  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  static String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

  /// `10월 20일 (화)`
  static String dayLabel(DateTime d) => '${d.month}월 ${d.day}일 (${weekdayName(d)})';
  static const free = '비어 있음';
  static String fixedPerson(String booker) => '고정 · $booker';
  static String remaining(int n) => '$n자리 남음';
  static const bookAction = '예약';
  static const cancelAction = '취소';
  static const booking = '예약 중…';
  static const canceling = '취소 중…';
  static String bookPeriod(String period) => '$period 예약';
  static String cancelPeriod(String period) => '$period 내 예약 취소';
  static String mine(String booker) => '내 예약 $booker';

  /// `1교시`·`2교시`면 `1·2교시`, 그 밖의 이름이 섞이면 이름을 `·`로 잇는다.
  static String periodNames(List<String> names) {
    final numbered = RegExp(r'^(\d+)교시$');
    final numbers = [for (final n in names) numbered.firstMatch(n)?.group(1)];
    if (numbers.every((n) => n != null)) return '${numbers.join('·')}교시';
    return names.join('·');
  }


  // 예약 · 취소 시트
  static const bookerLabel = '예약자';
  static const bookerHint = '5-1, 체육전담';
  static const passwordLabel = '비밀번호 (숫자 4자리)';
  static const book = '예약';
  static const cancelBooking = '예약 취소';
  static String bookSheetTitle(String room, String day, List<String> names) =>
      '$room · $day ${periodNames(names)}';
  static String cancelSheetTitle(String booker, String period) =>
      '$booker · $period 예약 취소';
  /// 어느 날·어느 교실인지 함께 말한다 — 요청 중에 다른 날로 옮겨도 알림이 헷갈리지 않게.
  static String booked(String room, DateTime day, List<String> names) =>
      '${dayLabel(day)} $room ${periodNames(names)}를 예약했어요';
  static const canceled = '예약을 취소했어요';
  static const alreadyCanceled = '이미 취소된 예약이에요';
  static const resultUnknown = '결과를 확인하지 못했어요. 목록을 확인해 주세요';
  static const bookFailed = '예약하지 못했어요';

  // 상세 설정
  static const settingsSchool = '연결된 학교';
  static const changeLink = '학교 링크 바꾸기';
  static const defaultBookerLabel = '예약자 이름';
  static const defaultBookerHint = '스쿨북 웹에서 쓰는 이름과 똑같이 — 같은 이름의 예약에 [취소]가 붙습니다';
  static const saveBooker = '저장';
  static const bookerSaved = '예약자 이름을 저장했어요';
  static const passwordFieldLabel = '예약 비밀번호 (숫자 4자리)';
  static const passwordFieldHint = '저장해 두면 예약·취소할 때 묻지 않습니다';
  static const passwordSaved = '저장한 비밀번호가 있어요';
  static const savePassword = '저장';
  static const clearPassword = '지우기';
  static const savedPasswordLabel = '저장한 비밀번호';
  static const revealPassword = '보기';
  static const hidePassword = '가리기';
  static const disconnect = '연결 끊기';
  static const disconnectNote = '앱에 저장한 학교 연결과 비밀번호만 지웁니다. 스쿨북의 예약은 그대로 남아요';
}
