/// 시간 축의 노선번호 라벨이 겹치지 않도록 x를 밀어낸다. **순수 함수.**
///
/// **점은 건드리지 않는다.** 시간 축의 존재 이유가 위치이므로 점은 진짜 시각에
/// 두고, 라벨만 최소 간격을 지키게 옮긴다. 라벨이 점에서 최대 [labelWidth]만큼
/// 어긋나지만 점이 바로 위에 있어 대응은 읽힌다.
///
/// **왜 필요한가**: 라벨 폭 34pt는 300pt 축에서 **1.7분치**다. 점끼리 겹치는 것은
/// 0.6분(12pt) 안쪽이라 드문데, 라벨은 1.7분 안이면 반드시 겹친다 — 실기기에서
/// 1분·1.5분 두 대가 `55536023`으로 뭉쳐 읽혔다(2026-07-30).
///
/// [centers]는 **오름차순**이어야 한다(호출부가 도착 순으로 정렬해 넘긴다).
/// 반환도 오름차순이 보장된다 — 순서가 뒤집히면 라벨이 남의 점 위에 선다.
List<double> layoutAxisLabels(
  List<double> centers,
  double labelWidth,
  double maxWidth,
) {
  if (centers.isEmpty) return const [];

  final lo = labelWidth / 2;
  final hi = maxWidth - labelWidth / 2;
  if (hi <= lo) return List.filled(centers.length, maxWidth / 2);

  // 다 펴도 안 들어가면 밀어내기로는 풀리지 않는다. 고르게 편다 —
  // 겹치더라도 순서와 화면 안이라는 두 가지는 지킨다.
  final needed = (centers.length - 1) * labelWidth;
  if (needed > hi - lo) {
    final step = (hi - lo) / (centers.length - 1);
    return [for (var i = 0; i < centers.length; i++) lo + step * i];
  }

  final out = List<double>.from(centers);

  // 왼→오: 앞 라벨과 최소 간격을 확보한다.
  out[0] = out[0] < lo ? lo : out[0];
  for (var i = 1; i < out.length; i++) {
    final min = out[i - 1] + labelWidth;
    if (out[i] < min) out[i] = min;
  }

  // 오→왼: 오른쪽 끝을 넘겼으면 되민다. 위에서 폭을 확인했으므로 이 되밀기가
  // 왼쪽 끝을 넘기는 일은 없다.
  if (out.last > hi) {
    out[out.length - 1] = hi;
    for (var i = out.length - 2; i >= 0; i--) {
      final max = out[i + 1] - labelWidth;
      if (out[i] > max) out[i] = max;
    }
  }

  return out;
}

/// 시간 축 라벨의 줄(0 = 윗줄, 1 = 아랫줄)을 정한다. **순수 함수.**
///
/// [sorted]는 도착 순 `(식별자, 점의 x)`이고 [previous]는 직전 프레임의 배정이다.
///
/// **버스가 한 번 받은 줄을 지킨다.** 짝·홀 순서로 정하면 맨 앞 버스가 지나가는 순간
/// 남은 라벨이 전부 줄을 바꿔, `AnimatedPositioned`가 그것을 1초짜리 위아래 미끄러짐으로
/// 재생했다(2026-10-09 점검). 점을 차량 키로 묶은 것과 같은 이유다 — 목록의 항목이
/// 교체되는 축과 위치를 세는 축이 같아야 한다.
///
/// 규칙:
/// - 왼쪽 이웃과 라벨 폭 안으로 붙어 있으면 이웃과 **다른 줄**이다.
/// - 붙은 묶음의 첫 라벨은 **기억한 줄**을 지킨다(없으면 윗줄) — 맨 앞 버스가 떠나도
///   남은 묶음이 뒤집히지 않는다.
/// - **혼자 떨어진 라벨은 늘 윗줄**이다. 아랫줄은 겹침을 피하는 자리일 뿐이라, 겹칠
///   이웃이 없는데 아랫줄에 두면 까닭 없이 내려간 것으로 보였다(실기기 신고 2026-10-09).
///
/// 같은 줄 안의 남은 겹침은 [layoutAxisLabels]가 가로로 밀어 푼다.
Map<String, int> assignLabelRows(
  List<(String, double)> sorted,
  Map<String, int> previous,
  double labelWidth,
) {
  final out = <String, int>{};
  for (var i = 0; i < sorted.length; i++) {
    final (id, center) = sorted[i];
    final nearLeft = i > 0 && center - sorted[i - 1].$2 < labelWidth;
    if (nearLeft) {
      out[id] = 1 - (out[sorted[i - 1].$1] ?? 0);
      continue;
    }
    final nearRight =
        i + 1 < sorted.length && sorted[i + 1].$2 - center < labelWidth;
    out[id] = nearRight ? (previous[id] ?? 0) : 0;
  }
  return out;
}
