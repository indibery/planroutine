/// 설정 탭의 일반 문자열 (알림·구글은 별도 파일).
class SettingsStrings {
  SettingsStrings._();

  static const title = '설정';

  // 화면 테마
  static const appearanceSection = '화면';
  static const themeLabel = '화면 테마';

  // 완료 도장 (오늘 탭)
  static const stampSection = '완료 도장';
  static const stampDescription = '오늘 탭에서 체크할 때 찍히는 도장';
  static const stampStyleLabel = '도장 모양';
  static const stampDimLabel = '이미 찍은 도장 흐리게';
  static const stampDimDescription = '방금 찍은 도장은 진하게, 지난 도장은 잔상으로';

  /// 도장 모양 시트 제목. 설정 탭의 행 라벨과 **같은 말이어야** 시트가 그 행의
  /// 연장으로 읽힌다 — 다른 말을 쓰면 다른 설정을 연 것처럼 보인다.
  static const stampStyleSheetTitle = stampStyleLabel;
  static const themeSystem = '시스템';
  static const themeLight = '밝게';
  static const themeDark = '어둡게';

  // 섹션 헤더
  static const exportSection = '현재 일정 내보내기';
  static const trashSection = '휴지통';
  static const dataSection = '데이터 관리';
  static const aboutSection = '앱 정보';

  /// 인앱 개인정보처리방침 링크. **Play User Data 정책이 요구하는 항목이다** —
  /// "a privacy policy link **or text** within the app itself".
  /// `/privacy_policy`는 **Google OAuth 동의 화면에 실제 등록된 값**이다(홈페이지
  /// 루트가 아니다 — 루트는 지원 페이지). 이 URL을 바꾸면 그 필드가 바뀌어
  /// **재검증 트리거가 된다**. 방침 본문만 고칠 때는 URL을 건드리지 않는다.
  static const privacyPolicyTitle = '개인정보처리방침';
  static const privacyPolicyUrl = 'https://planroutine.indibery.dev/privacy_policy';
  static const privacyPolicyFailed = '브라우저를 열 수 없습니다';

  /// 공공데이터 출처 표시 — **라이선스 의무다.**
  ///
  /// 서울특별시 API의 이용허락범위가 `저작자표시`(CC BY)이고 공공누리 제1유형
  /// (출처표시)이다. 경기도·국토교통부는 그 표기를 요구하지 않지만 함께 적는다 —
  /// 어느 데이터가 화면의 어느 숫자를 만들었는지 사용자가 알 수 있고, 소스가 바뀔 때
  /// 고칠 곳이 한 군데다.
  ///
  /// **실제로 호출하는 것만 적는다.** 서울 API는 신청·승인됐지만 아직 키가 등록되지
  /// 않아 호출하지 않는다 — 안 쓰는 기관을 출처로 적으면 그것도 거짓이다. 서울을
  /// 붙일 때 이 문구에 추가한다.
  static const dataSourceTitle = '데이터 출처';
  static const dataSourceBody =
      '버스 도착 정보 — 국토교통부(TAGO) · 경기도(GBIS)\n'
      '공공데이터포털에서 제공받았습니다';
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
      '일정과 캘린더 이벤트가 모두 삭제됩니다.\n'
      '알림·도장·정류장 등 앱 설정은 남습니다. 이 작업은 되돌릴 수 없습니다.';
  static const resetAllConfirm = '초기화';
  static const resetAllDone = '전체 데이터가 초기화되었습니다';
  static const resetAllFailed = '초기화 중 오류가 발생했습니다';
}
