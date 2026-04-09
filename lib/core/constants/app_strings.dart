/// 앱 전체에서 사용하는 문자열 상수
class AppStrings {
  AppStrings._();

  // 앱 기본
  static const appName = '플랜루틴';
  static const appNameEn = 'PlanRoutine';

  // 탭/네비게이션
  static const tabCalendar = '캘린더';
  static const tabImport = '가져오기';
  static const tabSchedule = '일정';
  static const tabCompare = '비교';

  // Import 기능
  static const importTitle = '작년 일정 가져오기';
  static const importDescription = 'CSV 파일을 업로드하여\n작년 업무 일정을 불러옵니다';
  static const importSelectFile = '파일 선택';
  static const importParsing = '파일 분석 중...';
  static const importSuccess = '가져오기 완료';
  static const importFailed = '가져오기 실패';
  static const importNoFile = '파일을 선택해주세요';
  static const importInvalidFormat = '올바른 CSV 형식이 아닙니다';
  static const importRegisterAll = '전체 등록';
  static const importRegisterSelected = '선택 등록';
  static const importRegisterDone = '등록 완료';
  static const importRegisterCount = '건 등록됨';
  static const importSelected = '건 선택';

  // Compare 기능
  static const compareTitle = '일정 비교';
  static const compareLastYear = '작년';
  static const compareThisYear = '올해';
  static const compareNoData = '비교할 데이터가 없습니다';
  static const compareExactMatch = '반영됨';
  static const compareSimilarMatch = '확인 필요';
  static const compareOnlyLastYear = '미반영';
  static const compareOnlyThisYear = '올해 신규';
  static const compareRegisterThisYear = '올해 일정으로 등록';
  static const compareSelectYear = '연도 선택';
  static const compareYearFormat = '년';
  static const compareDateChanged = '날짜 변경';
  static const compareTitleChanged = '제목 변경';

  // Schedule 기능
  static const scheduleTitle = '일정 검토';
  static const scheduleConfirm = '확정';
  static const scheduleConfirmAll = '전체 확정';
  static const scheduleDelete = '삭제';
  static const schedulePending = '검토 대기';
  static const scheduleConfirmed = '확정됨';
  static const scheduleCompleted = '완료';
  static const scheduleAll = '전체';
  static const scheduleEmpty = '등록된 일정이 없습니다';
  static const scheduleEmptyFiltered = '해당 조건의 일정이 없습니다';
  static const scheduleResetTitle = '전체 초기화';
  static const scheduleResetMessage = '등록된 일정을 모두 삭제합니다.\n이 작업은 되돌릴 수 없습니다.';
  static const scheduleResetConfirm = '초기화';
  static const scheduleResetDone = '전체 초기화 완료';
  static const scheduleBulkConfirmTitle = '일괄 확정';
  static const scheduleBulkConfirmMessage = '검토 대기 중인 일정을 모두 확정하시겠습니까?';
  static const scheduleDeleteConfirm = '이 일정을 삭제하시겠습니까?';
  static const scheduleEditTitle = '일정 수정';
  static const scheduleDescriptionHint = '설명 (선택사항)';
  static const scheduleDateLabel = '일정 날짜';
  static const scheduleTitleLabel = '제목';

  // Calendar 기능
  static const calendarTitle = '캘린더';
  static const calendarToday = '오늘';
  static const calendarAddEvent = '일정 추가';
  static const calendarEditEvent = '일정 수정';
  static const calendarNoEvents = '일정이 없습니다';
  static const calendarEventTitle = '제목';
  static const calendarEventTitleHint = '일정 제목을 입력하세요';
  static const calendarEventDescription = '설명';
  static const calendarEventDescriptionHint = '설명을 입력하세요 (선택)';
  static const calendarEventDate = '날짜';
  static const calendarEventEndDate = '종료 날짜';
  static const calendarEventAllDay = '종일';
  static const calendarEventColor = '색상';
  static const calendarDeleteConfirm = '이 일정을 삭제하시겠습니까?';
  static const calendarTitleRequired = '제목을 입력해주세요';

  // 요일
  static const weekdaySun = '일';
  static const weekdayMon = '월';
  static const weekdayTue = '화';
  static const weekdayWed = '수';
  static const weekdayThu = '목';
  static const weekdayFri = '금';
  static const weekdaySat = '토';

  // 공통
  static const save = '저장';
  static const cancel = '취소';
  static const delete = '삭제';
  static const edit = '수정';
  static const confirm = '확인';
  static const close = '닫기';
  static const retry = '다시 시도';
  static const loading = '로딩 중...';
  static const error = '오류가 발생했습니다';

  // 카테고리 (과제명)
  static const categoryAll = '전체';
  static const categoryDailyOps = '일과운영관리';
  static const categoryCurriculum = '교육과정계획수립운영';
  static const categoryOrganization = '조직및통계관리';
  static const categoryStudentRecord = '학생학적';
}
