/// 캘린더 화면 UI + 요일 축약 문자열.
class CalendarStrings {
  CalendarStrings._();

  static const title = '캘린더';
  static const addEvent = '일정 추가';
  static const editEvent = '일정 수정';
  static const noEvents = '일정이 없습니다';

  // 이벤트 편집 필드
  static const eventTitle = '제목';
  static const eventTitleHint = '일정 제목을 입력하세요';
  static const eventDescription = '설명';
  static const eventDescriptionHint = '설명을 입력하세요 (선택)';
  static const eventDate = '날짜';
  static const titleRequired = '제목을 입력해주세요';

  // Google 캘린더 저장
  static const saveToGoogle = 'Google 캘린더에도 저장';
  static const saveToGoogleShort = 'Google 저장';
  static const saveToGoogleNeedsSignIn = 'Google 로그인 후 저장';
  static const saveToGoogleNeedsSignInShort = 'Google 로그인';
  static const saveToGoogleDone = '구글 캘린더에 저장했습니다';
  static const saveToGoogleAlready = '이미 저장된 일정입니다';
  static const saveToGoogleFailed = '구글 캘린더 저장 실패';

  // 완료 토글
  static const markComplete = '일정 완료';
  static const undoComplete = '완료 취소';

  // 업무 / 행사
  static const kindLabel = '종류';

  // 가져온 자료 출처
  static const fromImportBadge = '작년';

  // 연도 바꾸기 칩 (연도가 둘 이상일 때)
  static const yearShiftAll = '연도 모두 +1년';

  // 중요 표시
  static const importantLabel = '중요 표시';
  static const importantBadge = '중요';

  // 스와이프
  static const swipeGoogleSave = 'Google 저장';
  static const swipeHintGoogle = '오른쪽으로 밀기 — Google 저장';
  static const swipeHintComplete = '왼쪽으로 밀기 — 완료';

  // 요일 축약
  static const weekdaySun = '일';
  static const weekdayMon = '월';
  static const weekdayTue = '화';
  static const weekdayWed = '수';
  static const weekdayThu = '목';
  static const weekdayFri = '금';
  static const weekdaySat = '토';

  /// 일요일부터 — `DateTime.weekday % 7`로 꺼낸다(일=0 … 토=6).
  static const weekdays = [
    weekdaySun,
    weekdayMon,
    weekdayTue,
    weekdayWed,
    weekdayThu,
    weekdayFri,
    weekdaySat,
  ];

  // 스크린리더·자동화 라벨 — 아이콘만 있는 버튼과 날짜 칸
  static const prevMonth = '이전 달';
  static const nextMonth = '다음 달';
  static const dayToday = '오늘';
  static const dayMemo = '포스트잇';
  static String dayDate(int month, int day, String weekday) =>
      '$month월 $day일 $weekday요일';
  static String dayEventCount(int n) => '일정 $n건';
  static const eventDone = '완료됨';
  static const goToday = '오늘로 이동';
}
