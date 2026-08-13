/// 캘린더 연동(외부 저장 대상 선택) 관련 문자열.
class CalendarIntegrationStrings {
  CalendarIntegrationStrings._();

  // 설정 섹션
  static const sectionTitle = '캘린더 연동';

  /// 행 제목. **`연동 대상`이 아니다** — 섹션 헤더(`캘린더 연동`)를 걷어내면서
  /// 그 행만 남으면 무엇에 대한 설정인지 알 수 없어진다. 헤더가 하던 말을
  /// 행이 넘겨받았다.
  static const targetLabel = '캘린더 연동';
  static const targetNone = '사용 안 함';
  static const targetGoogle = 'Google 캘린더';
  static const targetDevice = '기기 캘린더';

  // 권한 안내
  static const permissionGranted = '캘린더 권한 허용됨';
  static const permissionDenied = '캘린더 권한이 필요합니다';
  static const allowPermission = '권한 허용하기';
  static const openSettings = '설정에서 켜기';

  // 슬라이드 라벨/힌트 — device 전용. Google 라벨은 CalendarStrings 재사용.
  static const swipeSaveDevice = '기기 저장';
  static const swipeHintDevice = '오른쪽으로 밀기 — 기기 저장';

  // SnackBar
  static const setupNeeded = '캘린더 연동을 먼저 설정해주세요';

  /// **어느 캘린더에 저장했는지 이름을 밝힌다.** 앱이 캘린더를 대신 고르므로,
  /// 말해주지 않으면 "저장했다는데 구글 캘린더에 없다"가 된다 — 실기기에서
  /// 실제로 그랬다(로컬 `My calendar`로 갔다, 2026-08-06).
  ///
  /// 이름이 비면(플러그인이 안 주는 경우) 옛 문구로 떨어진다.
  static String savedDeviceTo(String calendarName) =>
      calendarName.isEmpty ? savedDevice : "'$calendarName'에 저장했습니다";

  static const savedDevice = '기기 캘린더에 저장했습니다';
  static const alreadySaved = '이미 저장된 일정입니다';

  /// 기기 캘린더 저장이 실패했을 때. **원인은 여기 담지 않는다** —
  /// 사용자가 손쓸 수 있는 것이 아니라서, 사유는 `debugPrint`로만 남긴다
  /// (`calendar_screen.dart`의 `on DeviceCalendarException`).
  static const saveFailed = '기기 캘린더에 저장하지 못했습니다';
}
