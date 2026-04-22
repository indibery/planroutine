/// 설정 탭의 일반 문자열 (알림·구글은 별도 파일).
class SettingsStrings {
  SettingsStrings._();

  static const title = '설정';

  // 섹션 헤더
  static const importSection = '작년 일정 가져오기';
  static const exportSection = '현재 일정 내보내기';
  static const trashSection = '휴지통';
  static const dataSection = '데이터 관리';
  static const aboutSection = '앱 정보';

  // 내보내기
  static const exportTitle = 'CSV로 내보내기';
  static const exportDescription = '올해 등록된 일정을 CSV 파일로 저장·공유합니다';
  static const exportEmpty = '내보낼 일정이 없습니다';
  static const exportFailed = '내보내기 중 오류가 발생했습니다';
  static const exportShareSubject = '공직플랜 일정';
  static const exportShareCountSuffix = '건의 일정을 공유합니다';

  // 휴지통 섹션 설명
  static const trashDescription = '삭제한 일정·캘린더 이벤트 (30일 후 자동 영구 삭제)';

  // 전체 초기화
  static const resetAll = '전체 데이터 초기화';
  static const resetAllConfirmTitle = '정말 초기화하시겠어요?';
  static const resetAllConfirmMessage =
      '모든 데이터가 영구 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.';
  static const resetAllConfirm = '초기화';
  static const resetAllDone = '전체 데이터가 초기화되었습니다';
  static const resetAllFailed = '초기화 중 오류가 발생했습니다';
}
