import 'bus_stop.dart';

/// 한 번에 그리는 검색 결과 상한.
///
/// 이름 검색은 결과가 감당이 안 된다 — 실측 `시청` 160곳, **`아파트` 4,366곳**. 상한이
/// 없으면 `ListView(children:)`이 4천 개 위젯을 만들고, 사용자는 그 안에서 자기 정류장을
/// 찾지 못한다(화면이 버텨도 사람이 못 쓴다).
///
/// 50인 이유: 지역 하나에 같은 이름이 10곳 남짓이므로(실측 `B정류장` 10곳) 지역을
/// 고른 뒤에는 상한에 걸리지 않는다. 즉 상한은 **좁히기 전 상태**만 자른다.
const stopSearchRenderCap = 50;

/// 지역 칩 상한. 결과에 33종이 나오는 경우가 있어(실측 `아파트`) 전부 그리면 칩이
/// 화면을 덮는다. 건수가 많은 쪽이 내 정류장을 담고 있을 확률이 높으므로 그 순서로 자른다.
///
/// 상한 밖 지역을 찾는 사람에게는 지역 칩이 답이 아니다 — 정류소번호를 넣는 것이 답이고
/// 화면이 그렇게 안내한다(`BusStrings.searchTooManyHint`).
const stopSearchRegionChipCap = 8;

/// 지역 칩 하나 — 이름과 그 지역의 결과 수.
class RegionCount {
  const RegionCount(this.name, this.count);

  final String name;
  final int count;

  @override
  String toString() => 'RegionCount($name, $count)';
}

/// 검색 결과를 화면이 그릴 수 있는 모양으로 정리한 것.
class StopSearchView {
  const StopSearchView({
    required this.visible,
    required this.regions,
    required this.total,
  });

  /// 실제로 그릴 목록 — 지역 필터와 상한이 적용됐다.
  final List<BusStop> visible;

  /// 지역 칩. 건수 내림차순, [stopSearchRegionChipCap]까지.
  ///
  /// **결과에 실제로 있는 지역만** 들어간다. TAGO 도시 목록(138개)과 무관하고 추가
  /// 조회도 없다 — 이미 받은 결과를 세기만 한다.
  final List<RegionCount> regions;

  /// 필터 전 전체 건수. [visible]과 다를 수 있다.
  final int total;

  /// 상한에 걸려 잘렸는가 — 그러면 화면이 좁히라고 말해야 한다.
  bool get truncated => visible.length < total;

  /// 지역 칩을 보여줄 만한가. 한 종류뿐이면 고를 것이 없다.
  bool get hasRegionChoice => regions.length >= 2;
}

/// 검색 결과 + 고른 지역 → 그릴 목록. **순수 함수다.**
///
/// [region]이 null이면 전체에서 상한까지, 값이 있으면 그 지역만 상한까지 준다.
/// 지역 칩은 **필터를 반영하지 않는다** — 반영하면 한 지역을 고른 순간 다른 칩의 건수가
/// 0이 되거나 사라져 되돌아갈 수 없다(입력 탭 종류 칩이 카테고리는 반영하고 종류는
/// 반영하지 않는 것과 같은 이유).
StopSearchView buildStopSearchView({
  required List<BusStop> stops,
  String? region,
}) {
  final counts = <String, int>{};
  for (final s in stops) {
    final name = s.regionName;
    // 지역명이 없는 결과(TAGO 경로)는 칩을 만들지 않는다 — 그 경로는 이미 도시를 골랐다.
    if (name == null || name.isEmpty) continue;
    counts[name] = (counts[name] ?? 0) + 1;
  }

  final regions =
      counts.entries.map((e) => RegionCount(e.key, e.value)).toList()
        // 건수 내림차순, 같으면 이름순 — 같은 결과에서 칩 순서가 흔들리지 않게.
        ..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          return byCount != 0 ? byCount : a.name.compareTo(b.name);
        });

  final filtered = region == null
      ? stops
      : stops.where((s) => s.regionName == region).toList();

  return StopSearchView(
    visible: filtered.take(stopSearchRenderCap).toList(),
    regions: regions.take(stopSearchRegionChipCap).toList(),
    total: filtered.length,
  );
}
