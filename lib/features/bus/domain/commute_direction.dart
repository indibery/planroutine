import '../../../core/constants/app_strings.dart';

/// 카드가 지금 보여주는 방향.
enum CommuteDirection {
  /// 집 → 학교. 출발지 슬롯을 본다.
  toWork(BusStrings.routeToWork, BusStrings.seeToHome),

  /// 학교 → 집. 도착지 슬롯을 본다.
  toHome(BusStrings.routeToHome, BusStrings.seeToWork);

  const CommuteDirection(this.label, this.otherLabel);

  /// 카드 제목줄에 쓰는 이름.
  final String label;

  /// 반대 방향으로 넘어가는 링크 문구.
  final String otherLabel;

  /// 이 방향이 채우는 슬롯 이름 — `출발지`/`도착지`.
  ///
  /// 검색 화면 제목과 확인 시트가 **같은 값**을 쓴다. 화면이 `출발지`라고 말하면서
  /// 도착지에 저장하는 어긋남이 구조적으로 생기지 않게, 라벨을 방향에서 한 번만 만든다.
  String get slotLabel =>
      this == CommuteDirection.toWork
          ? BusStrings.slotDeparture
          : BusStrings.slotArrival;

  CommuteDirection get flipped =>
      this == CommuteDirection.toWork ? CommuteDirection.toHome : CommuteDirection.toWork;

  /// `?slot=toWork` 쿼리 이름 → 방향. 모르는 값·null이면 **null**이다.
  ///
  /// 폴백 규칙은 enum이 든다(`EntryKind.fromValue`·`BusCardStyle.fromName`과 같은
  /// 자리) — 예전에는 이것만 `core/router`의 최상위 private 함수여서, 값을 추가하거나
  /// 쿼리 이름을 바꿀 때 고칠 곳 하나가 feature 밖에 숨어 있었다.
  ///
  /// **폴백이 값이 아니라 null인 이유**: 기본 슬롯을 고르는 것은 화면의 책임이다
  /// (`BusStopSearchScreen._slot`). 여기서 `toWork`로 메우면 '쿼리가 없었다'와
  /// '출근이라고 적혀 있었다'를 호출부가 구별할 수 없다.
  static CommuteDirection? fromName(String? name) {
    for (final direction in values) {
      if (direction.name == name) return direction;
    }
    return null;
  }
}
