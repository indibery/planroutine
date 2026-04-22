/// 캘린더 화면 UI + 요일 축약 문자열.
class CalendarStrings {
  CalendarStrings._();

  static const title = '캘린더';
  static const today = '오늘';
  static const addEvent = '일정 추가';
  static const editEvent = '일정 수정';
  static const noEvents = '일정이 없습니다';

  // 이벤트 편집 필드
  static const eventTitle = '제목';
  static const eventTitleHint = '일정 제목을 입력하세요';
  static const eventDescription = '설명';
  static const eventDescriptionHint = '설명을 입력하세요 (선택)';
  static const eventDate = '날짜';
  static const eventEndDate = '종료 날짜';
  static const eventAllDay = '종일';
  static const eventColor = '색상';
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
}
