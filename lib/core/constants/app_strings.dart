/// 앱 전체에서 사용하는 문자열 상수
class AppStrings {
  AppStrings._();

  // 앱 기본
  static const appName = '플랜루틴';

  // 탭/네비게이션
  static const tabCalendar = '캘린더';
  static const tabSchedule = '일정';

  // 설정 기능
  static const settingsTitle = '설정';
  static const settingsImportSection = '작년 일정 가져오기';
  static const settingsExportSection = '현재 일정 내보내기';
  static const settingsExportTitle = 'CSV로 내보내기';
  static const settingsExportDescription =
      '올해 등록된 일정을 CSV 파일로 저장·공유합니다';
  static const settingsExportEmpty = '내보낼 일정이 없습니다';
  static const settingsExportFailed = '내보내기 중 오류가 발생했습니다';
  static const settingsExportShareSubject = '플랜루틴 일정';
  static const settingsExportShareCountSuffix = '건의 일정을 공유합니다';
  static const settingsTrashSection = '휴지통';
  static const settingsTrashDescription =
      '삭제한 일정·캘린더 이벤트 (30일 후 자동 영구 삭제)';
  static const settingsNotificationSection = '알림';
  static const settingsNotificationMaster = '알림 사용';
  static const settingsNotificationMasterDescription =
      '월초·1주 전·1일 전에 알림을 보냅니다';
  static const settingsNotificationMonthStart = '월초 알림';
  static const settingsNotificationWeekBefore = '1주 전 알림';
  static const settingsNotificationDayBefore = '1일 전 알림';
  static const settingsNotificationTest = '테스트 알림 보내기';
  static const settingsNotificationTestDescription = '5초 후 알림이 발송됩니다';
  static const settingsNotificationTestScheduled =
      '5초 후 알림이 발송됩니다. 앱을 벗어나 대기해주세요';
  static const settingsGoogleSection = '구글 계정';
  static const settingsGoogleSignIn = '구글 캘린더 연결';
  static const settingsGoogleSignInDescription =
      '이벤트를 내 구글 캘린더로 내보낼 수 있습니다';
  static const settingsGoogleSignInFailed = '구글 로그인 실패';
  static const settingsGoogleSignOut = '로그아웃';
  static const settingsGoogleSignOutDone = '구글 계정이 연결 해제되었습니다';
  static const settingsDataSection = '데이터 관리';
  static const settingsAboutSection = '앱 정보';
  static const settingsResetAll = '전체 데이터 초기화';
  static const settingsResetAllDescription =
      '가져온 일정, 확정된 일정, 캘린더 이벤트를 모두 삭제합니다';
  static const settingsResetAllConfirmTitle = '정말 초기화하시겠어요?';
  static const settingsResetAllConfirmMessage =
      '모든 데이터가 영구 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.';
  static const settingsResetAllConfirm = '초기화';
  static const settingsResetAllDone = '전체 데이터가 초기화되었습니다';
  static const settingsResetAllFailed = '초기화 중 오류가 발생했습니다';

  // 가져오기 기능
  static const importDescription = 'CSV 파일을 업로드하여\n작년 업무 일정을 불러옵니다';
  static const importSelectFile = '파일 선택';
  static const importSelectFileAgain = '새 파일 가져오기';
  static const importParsing = '파일 분석 중...';
  static const importSuccess = '가져오기 완료';
  static const importFailed = '가져오기 실패';
  static const importRegisterAll = '전체 등록';
  static const importRegisterCount = '건 등록됨';

  // 비교 기능 (가져오기 요약 카드에서 연도 표기 등에 사용)
  static const compareYearFormat = '년';

  // 일정 검토 기능
  static const scheduleTitle = '일정 검토';
  static const scheduleConfirm = '확정';
  static const scheduleConfirmAll = '전체 확정';
  static const scheduleDelete = '삭제';
  static const schedulePending = '검토 대기';
  static const scheduleConfirmed = '확정됨';
  static const scheduleAll = '전체';
  static const scheduleEmpty = '등록된 일정이 없습니다';
  static const scheduleEmptyFiltered = '해당 조건의 일정이 없습니다';
  static const scheduleBulkConfirmTitle = '일괄 확정';
  static const scheduleBulkConfirmMessage = '검토 대기 중인 일정을 모두 확정하시겠습니까?';
  static const scheduleEditTitle = '일정 수정';
  static const scheduleDescriptionHint = '설명 (선택사항)';
  static const scheduleDateLabel = '일정 날짜';
  static const scheduleTitleLabel = '제목';
  static const scheduleSlideHintConfirm = '오른쪽으로 밀기 — 확정';
  static const scheduleSlideHintDelete = '왼쪽으로 밀기 — 삭제';

  // 캘린더 기능
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
  static const calendarTitleRequired = '제목을 입력해주세요';
  static const calendarSaveToGoogle = 'Google 캘린더에도 저장';
  static const calendarSaveToGoogleShort = 'Google 저장';
  static const calendarSaveToGoogleNeedsSignIn = 'Google 로그인 후 저장';
  static const calendarSaveToGoogleNeedsSignInShort = 'Google 로그인';
  static const calendarSaveToGoogleDone = '구글 캘린더에 저장했습니다';
  static const calendarSaveToGoogleFailed = '구글 캘린더 저장 실패';
  static const calendarMarkComplete = '일정 완료';
  static const calendarUndoComplete = '완료 취소';
  static const calendarSwipeGoogleSave = 'Google 저장';
  static const calendarSwipeHintGoogle = '오른쪽으로 밀기 — Google 저장';
  static const calendarSwipeHintComplete = '왼쪽으로 밀기 — 완료';

  // 휴지통
  static const trashTitle = '휴지통';
  static const trashEmpty = '휴지통이 비어있습니다';
  static const trashAutoPurgeNotice = '삭제 후 30일 뒤 자동 영구 삭제됩니다';
  static const trashSectionSchedules = '일정';
  static const trashSectionEvents = '캘린더 이벤트';
  static const trashRestore = '복구';
  static const trashPermanentDelete = '영구 삭제';
  static const trashPermanentDeleteTitle = '영구 삭제하시겠어요?';
  static const trashPermanentDeleteMessage =
      '이 항목은 복구할 수 없게 됩니다.';
  static const trashDeletedPrefix = '삭제 ';

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
  static const retry = '다시 시도';
  static const loading = '로딩 중...';
  static const error = '오류가 발생했습니다';

  // 카테고리 매칭용 리터럴 (색상 결정 등)
  static const categoryDailyOps = '일과운영관리';
}
