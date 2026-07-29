import '../../../core/constants/app_strings.dart';

/// 카드가 지금 보여주는 방향.
enum CommuteDirection {
  /// 집 → 학교. 출발지 슬롯을 본다.
  toWork(BusStrings.routeToWork, BusStrings.routeToWorkShort, BusStrings.seeToHome),

  /// 학교 → 집. 도착지 슬롯을 본다.
  toHome(BusStrings.routeToHome, BusStrings.routeToHomeShort, BusStrings.seeToWork);

  const CommuteDirection(this.label, this.shortLabel, this.otherLabel);

  /// 카드 제목줄에 쓰는 이름.
  final String label;

  /// 좁은 폭에서 쓰는 이름 — 이모지가 없다. 판정은 `BusArrivalCard._header`가 한다.
  final String shortLabel;

  /// 반대 방향으로 넘어가는 링크 문구.
  final String otherLabel;

  CommuteDirection get flipped =>
      this == CommuteDirection.toWork ? CommuteDirection.toHome : CommuteDirection.toWork;
}
