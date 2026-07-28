/// 카드 본문 모양. 설정 탭에서 고른다.
///
/// `SealStyle`과 같은 구조다 — 모양 규칙을 enum이 들고 위젯은 enum만 보고 그린다.
enum BusCardStyle {
  /// 간단히 — 한 줄에 노선을 나열하고 임박을 굵기·크기로만 낸다. **기본값.**
  ///
  /// 새 색 토큰이 0개고, 가장 낮고, 노선 수·배차 간격 어떤 조건에서도 깨지지 않는다.
  text('간단히'),

  /// 시간 축 — 0~15분 축에 점으로. 간격이 공간으로 보인다.
  ///
  /// 두 버스가 3분 안으로 붙으면 점과 라벨이 겹치고 15분 넘는 버스는 오른쪽 끝에
  /// 몰리므로 조건이 맞는 사람이 고르는 선택지다.
  axis('시간 축', usesSignalColors: true);

  const BusCardStyle(this.label, {this.usesSignalColors = false});

  /// 설정 화면 세그먼트에 표시할 이름.
  final String label;

  /// `AppColors.busSignal*`을 참조하는 모양인지.
  ///
  /// 기본값(`text`)이 false라 켜지 않은 사용자와 기본 모양 사용자에게 팔레트는
  /// 지금과 완전히 같다. 가드 테스트가 이 사실을 지킨다.
  final bool usesSignalColors;
}
