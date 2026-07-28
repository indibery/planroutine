import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/tago_response_parser.dart';
import '../../domain/bus_arrival.dart';
import '../../domain/bus_card_view.dart';
import '../../domain/bus_stop.dart';
import '../../domain/commute_direction.dart';
import '../providers/bus_providers.dart';

/// 도시 선택 → 정류장 이름 검색 → 확인 시트 → 슬롯 저장.
///
/// GPS 근접 검색을 쓰지 않는다. 슬롯을 **교체**하는 순간(전근·이사)에는 대상
/// 정류장 근처에 없는 것이 기본값이라 GPS가 못 쓰인다 — 이름 검색만 항상 작동한다.
class BusStopSearchScreen extends ConsumerStatefulWidget {
  const BusStopSearchScreen({super.key, this.slot});

  /// 채울 슬롯. `/bus/stops?slot=toWork` 쿼리로 넘어온다.
  final CommuteDirection? slot;

  static const cityFieldKey = Key('bus_city_field');
  static const stopFieldKey = Key('bus_stop_field');
  static const confirmAcceptKey = Key('bus_confirm_accept');

  @override
  ConsumerState<BusStopSearchScreen> createState() =>
      _BusStopSearchScreenState();
}

class _BusStopSearchScreenState extends ConsumerState<BusStopSearchScreen> {
  final _cityFilter = TextEditingController();
  final _stopQuery = TextEditingController();

  List<CityCode> _cities = const [];
  CityCode? _city;
  List<BusStop> _results = const [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _cityFilter.dispose();
    _stopQuery.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    setState(() => _loading = true);
    final result = await ref.read(busApiClientProvider).fetchCities();
    if (!mounted) return;
    setState(() {
      _cities = result.items;
      _loading = false;
      // 마지막으로 쓴 도시를 기본 선택으로 — 교체할 때 다시 고르지 않는다.
      final saved = ref.read(busSettingsProvider).valueOrNull;
      final code = saved?.departure?.cityCode ?? saved?.arrival?.cityCode;
      final matched = _cities.where((c) => c.code == code).toList();
      _city = matched.isEmpty ? null : matched.first;
    });
  }

  Future<void> _search() async {
    final city = _city;
    final name = _stopQuery.text.trim();
    if (city == null || name.isEmpty) return;

    setState(() => _loading = true);
    final result = await ref
        .read(busApiClientProvider)
        .searchStops(cityCode: city.code, name: name);
    if (!mounted) return;
    setState(() {
      _results = result.items;
      _loading = false;
      _searched = true;
    });
  }

  /// 정류장을 탭했을 때 — 바로 저장하지 않고 오는 버스를 조회해 확인받는다.
  Future<void> _pick(BusStop stop) async {
    setState(() => _loading = true);
    final fetch = await ref
        .read(busApiClientProvider)
        .fetchArrivals(cityCode: stop.cityCode, nodeId: stop.nodeId);
    if (!mounted) return;
    setState(() => _loading = false);

    final confirmed = await BusStopConfirmSheet.show(
      context,
      stop: stop,
      arrivals: fetch.arrivals,
      // 빈 목록의 이유를 시트가 알아야 한다 — `fetchArrivals`는 예외를 던지지 않고
      // 실패를 상태로 돌려주므로, state를 버리면 장애와 막차 후가 구별되지 않는다.
      state: fetch.state,
    );
    if (confirmed == null || !mounted) return;

    // 쿼리가 없으면 출근 슬롯 — 호출부는 전부 `?slot=`을 붙인다(Task 12·14).
    // 이 폴백은 라우트를 손으로 열었을 때의 마지막 안전망이다.
    final slot = widget.slot ?? CommuteDirection.toWork;
    await ref.read(busSettingsProvider.notifier).setStop(slot, confirmed);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cities = _cityFilter.text.trim().isEmpty
        ? _cities
        : _cities
            .where((c) => c.name.contains(_cityFilter.text.trim()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(BusStrings.searchTitle, style: AppTextStyles.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.spacing48),
        children: [
          _cityPicker(cities),
          const Divider(height: 1),
          _stopSearchField(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSizes.spacing24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._resultRows(),
        ],
      ),
    );
  }

  /// 도시코드는 시·군 단위로 전국 138개다 — 스크롤만으로 고르게 하면 마찰이 크므로
  /// 검색 필드를 둔다.
  Widget _cityPicker(List<CityCode> cities) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(BusStrings.cityLabel, style: AppTextStyles.eyebrow),
          const SizedBox(height: AppSizes.spacing8),
          TextField(
            key: BusStopSearchScreen.cityFieldKey,
            controller: _cityFilter,
            decoration: InputDecoration(hintText: BusStrings.citySearchHint),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSizes.spacing8),
          Wrap(
            spacing: AppSizes.spacing8,
            runSpacing: AppSizes.spacing4,
            children: _chipCities(cities).map((c) {
              final selected = c.code == _city?.code;
              return ChoiceChip(
                label: Text(c.name),
                selected: selected,
                onSelected: (_) => setState(() => _city = c),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 칩으로 그릴 도시 — **선택된 도시는 항상 맨 앞에 남긴다.**
  ///
  /// 138개를 다 그리면 화면이 칩으로 덮이므로 상한(20)을 둔다. 그런데 목록이
  /// citycode 오름차순 원본이라 상한만 두면 경기 후반(31110~)·강원 이남은 구조적으로
  /// 밖으로 밀린다 — 마지막으로 쓴 도시를 복원해 놓고도 선택된 칩이 화면에 없어
  /// "안 골라졌다"고 읽히고, 사용자가 엉뚱한 칩으로 갈아치운다. 선택된 것을 앞으로
  /// 끌어올리면 "다시 고르지 않는다"는 약속이 실제로 지켜진다.
  List<CityCode> _chipCities(List<CityCode> cities) {
    const limit = 20;
    final selected = _city;
    // 선택된 도시가 지금 목록(= 필터 결과)에 없으면 끌어오지 않는다 — 필터에 맞지도
    // 않는 칩이 맨 앞에 뜨면 그것이 검색 결과처럼 읽힌다.
    if (selected == null || !cities.any((c) => c.code == selected.code)) {
      return cities.take(limit).toList();
    }
    return [
      selected,
      ...cities.where((c) => c.code != selected.code).take(limit - 1),
    ];
  }

  Widget _stopSearchField() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: TextField(
        key: BusStopSearchScreen.stopFieldKey,
        controller: _stopQuery,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: BusStrings.stopSearchHint,
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ),
        onSubmitted: (_) => _search(),
      ),
    );
  }

  List<Widget> _resultRows() {
    if (!_searched) {
      return [_notice(BusStrings.searchPrompt)];
    }
    if (_results.isEmpty) {
      return [_notice(BusStrings.searchEmpty)];
    }
    return _results
        .map((stop) => ListTile(
              title: Text(stop.nodeNm),
              subtitle: Text('${stop.nodeNo}'),
              trailing: Icon(Icons.chevron_right, color: AppColors.faint),
              onTap: () => _pick(stop),
            ))
        .toList();
  }

  Widget _notice(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing24,
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            color: AppColors.sub,
          ),
        ),
      ),
    );
  }
}

/// 저장 직전 확인 — 방향이 조용히 틀리는 것을 막는다.
///
/// 실측: `수원시청.수원일자리센터`가 `GGB201000156`과 `GGB202000003` 두 개이고
/// 좌표 차이는 약 60m다. 이름으로도 좌표로도 사람이 고를 수 없지만 **자기가 타는
/// 버스 번호는 안다.** 잘못 고르면 화면에는 버스가 정상적으로 뜨는데 전부 반대
/// 방향이라, 사용자는 앱이 고장 났다고 생각하지 않고 자기가 늦었다고 생각한다.
class BusStopConfirmSheet extends StatefulWidget {
  const BusStopConfirmSheet({
    super.key,
    required this.stop,
    required this.arrivals,
    required this.state,
  });

  final BusStop stop;
  final List<BusArrival> arrivals;

  /// 조회 결과 상태. **빈 목록의 이유를 구분하는 데만 쓴다.**
  ///
  /// `arrivals`가 비는 경로는 두 가지고 뜻이 정반대다: 막차 후처럼 **정말 안 오는
  /// 경우**(`ok`·`closed`)와 네트워크·키 문제로 **못 물어본 경우**(`down`·`keyError`).
  /// 뭉개면 조회 실패 순간 사용자는 "이 정류장에 오는 버스가 없어요"를 읽고 방향을
  /// 전혀 확인하지 못한 채 저장한다 — 시트를 만든 이유가 실패 경로에서 정확히
  /// 무너진다(반대 방향 정류장이 저장되고, 사용자는 앱이 아니라 자기가 늦었다고
  /// 생각한다).
  final BusCardState state;

  static Future<BusStop?> show(
    BuildContext context, {
    required BusStop stop,
    required List<BusArrival> arrivals,
    required BusCardState state,
  }) {
    return showModalBottomSheet<BusStop>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BusStopConfirmSheet(
        stop: stop,
        arrivals: arrivals,
        state: state,
      ),
    );
  }

  @override
  State<BusStopConfirmSheet> createState() => _BusStopConfirmSheetState();
}

class _BusStopConfirmSheetState extends State<BusStopConfirmSheet> {
  late Set<String> _checked;

  /// 못 물어본 것인가. 이때는 확인할 재료가 0이므로 저장을 막는다.
  bool get _fetchFailed =>
      widget.state == BusCardState.down || widget.state == BusCardState.keyError;

  @override
  void initState() {
    super.initState();
    // 기본은 전부 체크 — 방향만 확인하려는 사람이 `맞아요`만 눌러도 되게.
    _checked = widget.arrivals.map((a) => a.routeId).toSet();
  }

  void _accept() {
    if (widget.arrivals.isNotEmpty && _checked.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text(BusStrings.confirmNeedRoute)));
      return;
    }

    // 전부 체크된 상태는 **빈 집합**으로 저장한다. 열거해 저장하면 "전부"가
    // "이 다섯 개"로 굳어 노선이 신설됐을 때 영구히 안 보인다.
    final all = widget.arrivals.map((a) => a.routeId).toSet();
    final selected = _checked.length == all.length ? <String>{} : _checked;

    Navigator.of(context).pop(widget.stop.copyWith(routeIds: selected));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(BusStrings.confirmTitle, style: AppTextStyles.heading),
            const SizedBox(height: AppSizes.spacing8),
            Text(
              '${widget.stop.nodeNm}  ${widget.stop.nodeNo}',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            if (_fetchFailed)
              // 못 물어본 경우 — 카드의 실패 문구를 그대로 쓴다. 시트용 문구를
              // 따로 만들지 않는 이유: 사용자가 읽는 사실이 같다("지금 정보를 못
              // 받았어요"), 그리고 문구가 갈라지면 둘 중 하나만 손보게 된다.
              Text(
                widget.state == BusCardState.keyError
                    ? BusStrings.emptyKey
                    : BusStrings.emptyDown,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  color: AppColors.sub,
                ),
              )
            else if (widget.arrivals.isEmpty)
              Text(
                BusStrings.confirmNoRoutes,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  color: AppColors.sub,
                ),
              )
            else ...[
              Text(BusStrings.confirmRoutesTitle,
                  style: AppTextStyles.eyebrow),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: widget.arrivals.map(_routeTile).toList(),
                ),
              ),
            ],
            const SizedBox(height: AppSizes.spacing16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(BusStrings.confirmReject),
                  ),
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: ElevatedButton(
                    key: BusStopSearchScreen.confirmAcceptKey,
                    // 조회 실패면 저장할 수 없다 — 방향을 확인할 재료가 없는데
                    // 저장을 허용하면 시트가 통과 도장이 된다. 사용자는 `아니에요`로
                    // 닫고 다시 고르면 그때 새로 조회한다.
                    onPressed: _fetchFailed ? null : _accept,
                    child: const Text(BusStrings.confirmAccept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeTile(BusArrival arrival) {
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: _checked.contains(arrival.routeId),
      onChanged: (on) => setState(() {
        if (on ?? false) {
          _checked.add(arrival.routeId);
        } else {
          _checked.remove(arrival.routeId);
        }
      }),
      title: Text('${arrival.routeNo}번'),
      secondary: Text(
        arrival.arrMin == 0
            ? BusStrings.arrivingNow
            : '${BusStrings.minutes(arrival.arrMin)} 후',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          color: AppColors.sub,
        ),
      ),
    );
  }
}
