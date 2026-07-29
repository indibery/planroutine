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

  CommuteDirection get flipped =>
      this == CommuteDirection.toWork ? CommuteDirection.toHome : CommuteDirection.toWork;
}
