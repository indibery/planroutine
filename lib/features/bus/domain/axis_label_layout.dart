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
