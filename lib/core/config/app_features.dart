/// 앱 전역 기능 플래그.
///
/// 특정 기능을 런타임에 on/off 하거나, 심사·승인 등 외부 조건에 따라 단계적으로
/// 노출하기 위한 구성 값 모음. 플래그를 끄면 관련 UI 진입점이 사라지며 해당
/// 기능의 코드·패키지·Info.plist 항목은 그대로 유지돼 승인 완료 시 한 줄 변경
/// + 재배포로 즉시 복원할 수 있다.
class AppFeatures {
  AppFeatures._();

  /// Google Calendar 단방향 저장 기능.
  ///
  /// Google OAuth `calendar.events` scope의 verification 심사가 진행 중이라
  /// 앱스토어 첫 출시(v1.0.0)에서는 false로 두고 UI 진입점을 모두 숨긴다.
  /// 심사 승인 완료 후 true로 전환하고 v1.0.1 업데이트로 배포.
  ///
  /// 영향 UI:
  /// - 설정 탭 "구글 계정" 섹션
  /// - 캘린더 이벤트 오른쪽 스와이프(→ Google 저장)
  /// - 캘린더 상단 스와이프 힌트 바
  static const bool googleCalendarEnabled = true;
}
