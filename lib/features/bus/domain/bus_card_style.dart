import '../../../core/constants/app_strings.dart';

/// 카드 본문 모양. 설정 탭에서 고른다.
///
/// 값 자체가 모양을 뜻하고 `BusArrivalCard._body()`의 `switch`가 위젯을 고른다 —
/// enum이 드는 것은 **표시 이름 하나**다(`SealStyle`은 `isSquare`·`usesIcon`처럼
/// 위젯이 읽는 규칙도 들지만, 여기서는 그럴 규칙이 없다).
enum BusCardStyle {
  /// 간단히 — 한 줄에 노선을 나열하고 임박을 굵기·크기로만 낸다. **기본값.**
  ///
  /// 새 색 토큰이 0개고, 가장 낮고, 노선 수·배차 간격 어떤 조건에서도 깨지지 않는다.
  /// **기본 모양은 신호색을 쓰지 않는다** — `bus_body_test.dart`가 `bus_body_text.dart`
  /// 소스에 신호색 토큰 이름이 없는지 검사하는 가드로 그 사실을 지킨다(enum 필드로
  /// 적어두는 것은 선언을 되읽는 항진 단정일 뿐 화면을 지키지 못한다).
  text(BusStrings.styleText),

  /// 시간 축 — 0~15분 축에 점으로. 간격이 공간으로 보인다.
  ///
  /// 두 버스가 3분 안으로 붙으면 점과 라벨이 겹치고 15분 넘는 버스는 오른쪽 끝에
  /// 몰리므로 조건이 맞는 사람이 고르는 선택지다. 신호색은 `BusBodyAxis`가 직접
  /// 참조한다.
  axis(BusStrings.styleAxis);

  const BusCardStyle(this.label);

  /// 설정 화면 세그먼트에 표시할 이름.
  final String label;

  /// 저장된 이름 → enum. 모르는 값·null(구버전·손상)은 기본 모양으로 폴백한다.
  ///
  /// 폴백 규칙은 **enum이 든다** — `EntryKind.fromValue`와 같은 자리다. 읽는 쪽
  /// (`BusSettings.fromJson`)에 두면 같은 일을 하는 파서가 파일마다 다른 모양으로
  /// 늘어난다.
  static BusCardStyle fromName(String? name) {
    return values.firstWhere(
      (style) => style.name == name,
      orElse: () => BusCardStyle.text,
    );
  }
}
