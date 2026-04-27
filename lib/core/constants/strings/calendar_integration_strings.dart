/// 캘린더 연동(외부 저장 대상 선택) 관련 문자열.
class CalendarIntegrationStrings {
  CalendarIntegrationStrings._();

  // 설정 섹션
  static const sectionTitle = '캘린더 연동';
  static const targetLabel = '연동 대상';
  static const targetNone = '사용 안 함';
  static const targetGoogle = 'Google 캘린더';
  static const targetDevice = '기기 캘린더';

  // 권한 안내
  static const permissionGranted = '캘린더 권한 허용됨';
  static const permissionDenied = '캘린더 권한이 필요합니다';
  static const openSettings = '설정에서 켜기';

  // 슬라이드 라벨/힌트 — target에 따라 분기
  static const swipeSaveGoogle = 'Google 저장';
  static const swipeSaveDevice = '기기 저장';
  static const swipeHintGoogle = '오른쪽으로 밀기 — Google 저장';
  static const swipeHintDevice = '오른쪽으로 밀기 — 기기 저장';

  // SnackBar
  static const setupNeeded = '캘린더 연동을 먼저 설정해주세요';
  static const savedGoogle = 'Google 캘린더에 저장했습니다';
  static const savedDevice = '기기 캘린더에 저장했습니다';
  static const alreadySaved = '이미 저장된 일정입니다';
  static const saveFailed = '저장 실패';
}
