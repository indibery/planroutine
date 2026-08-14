/// 앱 전체 크기/간격 상수
class AppSizes {
  AppSizes._();

  // 간격 (padding/margin)
  static const spacing4 = 4.0;
  static const spacing8 = 8.0;
  static const spacing12 = 12.0;
  static const spacing16 = 16.0;
  static const spacing20 = 20.0;
  static const spacing24 = 24.0;
  static const spacing32 = 32.0;
  static const spacing48 = 48.0;

  // 모서리 둥글기
  static const radius4 = 4.0;
  static const radius8 = 8.0;
  static const radius12 = 12.0;
  static const radius16 = 16.0;
  static const radiusFull = 999.0;

  // 아이콘
  static const iconSmall = 16.0;
  static const iconMedium = 24.0;
  static const iconLarge = 32.0;

  // 버튼
  static const buttonHeight = 48.0;
  static const buttonHeightSmall = 36.0;

  // 카드
  static const cardElevation = 1.0;

  // 앱바
  static const appBarHeight = 56.0;

  // ── 디자인 시스템 토큰 ───────────────────────────────────
  static const pagePadding = 20.0;
  static const cardPadding = 16.0;
  static const cardGap = 8.0;
  static const sectionGap = 24.0;

  static const radius14 = 14.0;
  static const radius18 = 18.0;
  static const radius28 = 28.0;
  static const radiusPill = 999.0;

  static const fabSize = 56.0;
  static const tabBarHeight = 72.0;

  // ── 입력 탭 일괄등록 바 ──────────────────────────────────
  /// 일괄등록 pill 한 개의 높이.
  static const bulkRegisterPillHeight = 40.0;

  /// 일괄등록 바 전체 높이 — 위 여백 + pill + 아래 여백.
  ///
  /// 붙여넣기 결과 스낵바를 **이 바 위로** 띄우는 데 쓴다. 기본값(fixed) 스낵바는
  /// 화면 맨 아래에 앉는데 그 자리가 정확히 이 바라, 4초 동안 확정을 못 누른다
  /// (사용자 신고 2026-08-14). 숫자를 스낵바 쪽에 따로 박으면 pill 높이를 바꿀 때
  /// 조용히 어긋나므로 여기서 파생시킨다.
  static const bulkRegisterBarHeight =
      spacing8 + bulkRegisterPillHeight + spacing12;

  // ── 캘린더 그리드 ────────────────────────────────────────
  /// 날짜 셀 한 칸 높이. dot 유무로 행 높이가 흔들리지 않게 명시한다.
  static const calendarCellHeight = 34.0;

  /// 요일 헤더 글자 높이(약 17) + 헤더~그리드 간격 + 폰트 메트릭 여유.
  static const calendarHeaderHeight = 17.0;

  /// PageView가 요구하는 그리드 영역 고정 높이 — 6행 기준.
  /// 셀 높이를 바꾸면 여기가 함께 따라와야 실제 주가 잘리지 않는다.
  static const calendarGridHeight =
      calendarCellHeight * 6 + calendarHeaderHeight + spacing4 + 5;
}
