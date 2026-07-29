import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/pill_chip.dart';
import '../../data/tago_response_parser.dart';
import '../../domain/bus_stop.dart';
import '../../domain/commute_direction.dart';
import '../providers/bus_providers.dart';
import '../widgets/bus_stop_confirm_sheet.dart';

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

  /// 조회가 **실패**한 이유. null이면 실패하지 않았다.
  ///
  /// `outcome`을 버리면 네트워크·키 장애가 `검색 결과가 없어요`로 뭉개져, 사용자는
  /// 이름을 고치며 헛수고한다 — 확인 시트가 `state`로 실패를 구분하게 만든 것과
  /// 같은 이유다. `empty`는 실패가 아니다(정말 그 이름의 정류장이 없다).
  TagoOutcome? _cityFailure;
  TagoOutcome? _stopFailure;

  /// 채울 슬롯. **표시와 저장이 같은 값을 본다** — 화면이 `출발지`라고 말하면서
  /// 도착지에 저장하는 어긋남이 구조적으로 생기지 않는다.
  ///
  /// 쿼리가 없으면 출근 슬롯이다. 호출부는 전부 `?slot=`을 붙이므로(Task 12·14)
  /// 이 폴백은 라우트를 손으로 열었을 때의 마지막 안전망이고, 그때도 제목과 시트가
  /// 같은 이름을 말한다.
  CommuteDirection get _slot => widget.slot ?? CommuteDirection.toWork;

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
    setState(() {
      _loading = true;
      _cityFailure = null;
    });
    final result = await ref.read(busApiClientProvider).fetchCities();
    if (!mounted) return;
    setState(() {
      _cities = result.items;
      _loading = false;
      // 칩이 0개인 이유가 '도시가 없다'가 아니라 '못 물어봤다'일 수 있다. 도시를
      // 못 고르면 이 화면에서 할 수 있는 일이 없으므로 ok가 아닌 모든 결과를
      // 실패로 말하고 재시도를 준다(TAGO는 정상이면 전국 138개를 준다).
      _cityFailure = result.outcome == TagoOutcome.ok ? null : result.outcome;
      // **편집 중인 슬롯의** 도시를 먼저, 없으면 반대 슬롯 — 두 슬롯이 다 등록된
      // 뒤 도착지를 고치는데 출발지의 도시가 복원되면, 잘못된 cityCode는 오류가
      // 아니라 빈 응답으로 와서 `검색 결과가 없어요` 한 번을 헛치게 된다.
      final saved = ref.read(busSettingsProvider).valueOrNull;
      final code = saved?.stopFor(_slot)?.cityCode ??
          saved?.stopFor(_slot.flipped)?.cityCode;
      final matched = _cities.where((c) => c.code == code).toList();
      _city = matched.isEmpty ? null : matched.first;
    });
  }

  /// 도시를 바꾼다 — **옛 도시의 결과를 함께 버린다.**
  ///
  /// 안 버리면 성남시가 강조된 칩 아래 수원시 목록이 깔린다. 검색어가 남아 있으면
  /// 곧바로 새 도시로 다시 찾는다(그러지 않으면 이름을 넣어둔 채 `정류장 이름을
  /// 입력해 주세요`가 떠, 도시를 고르기 전 검색과 같은 종류의 거짓말이 된다).
  void _selectCity(CityCode city) {
    setState(() {
      _city = city;
      _results = const [];
      _searched = false;
      _stopFailure = null;
    });
    if (_stopQuery.text.trim().isNotEmpty) _search();
  }

  Future<void> _search() async {
    final city = _city;
    final name = _stopQuery.text.trim();
    // 도시를 고르기 전에는 돋보기가 비활성이고 화면이 `먼저 도시를 골라주세요`를
    // 띄우므로, 여기서 조용히 return해도 사용자는 이유를 읽는다.
    if (city == null || name.isEmpty) return;

    setState(() {
      _loading = true;
      _stopFailure = null;
    });
    final result = await ref
        .read(busApiClientProvider)
        .searchStops(cityCode: city.code, name: name);
    if (!mounted) return;
    setState(() {
      _results = result.items;
      _loading = false;
      _searched = true;
      // `empty`를 실패로 말하면 사용자가 이름을 고치는 대신 무한히 재시도한다.
      _stopFailure = switch (result.outcome) {
        TagoOutcome.ok || TagoOutcome.empty => null,
        TagoOutcome.keyError || TagoOutcome.malformed => result.outcome,
      };
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
      // 저장 대상을 시트도 말한다 — `맞아요`를 누르는 순간이 되돌리기 가장 어려운
      // 지점이고, 이 값이 곧 아래 `setStop`의 대상이다.
      slot: _slot,
    );
    if (confirmed == null || !mounted) return;

    await ref.read(busSettingsProvider.notifier).setStop(_slot, confirmed);
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
        title: Text(
          BusStrings.searchTitleFor(_slot.slotLabel),
          style: AppTextStyles.heading,
        ),
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
          // eyebrow(자간 2.5 + 골드)는 영문 대문자 소제목용이다 — 한글 두 글자에
          // 쓰면 `도 시`처럼 벌어진다.
          Text(BusStrings.cityLabel, style: AppTextStyles.label),
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
            // 리포의 선택 가능한 칩은 전부 `PillChip`이다. raw `ChoiceChip`은
            // `chipTheme.labelStyle`이 선택/비선택 구분 없는 `sub` 상수라 선택 채움
            // (골드) 위에 크림 글씨가 얹혀 다크에서 대비 1.10:1로 사라진다 —
            // 방금 고른 도시 이름이 안 읽힌다.
            children: _chipCities(cities).map((c) {
              return PillChip(
                label: c.name,
                selected: c.code == _city?.code,
                onTap: () => _selectCity(c),
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
            // 도시를 고르기 전에는 조회가 나갈 수 없다 — 활성처럼 보이면 눌러도
            // 아무 일이 없는 죽은 컨트롤이 되고, 첫 등록은 반드시 이 상태를 지난다.
            onPressed: _city == null ? null : _search,
          ),
        ),
        onSubmitted: (_) => _search(),
      ),
    );
  }

  List<Widget> _resultRows() {
    // 순서가 계약이다: 못 물어본 것 → 고를 수 없는 것 → 아직 안 찾은 것 →
    // 찾았지만 실패 → 정말 없음. 뒤섞으면 각 문구가 다른 상황을 덮는다.
    final cityFailure = _cityFailure;
    if (cityFailure != null) {
      return [_notice(_failureMessage(cityFailure), onRetry: _loadCities)];
    }
    if (_city == null) {
      return [_notice(BusStrings.cityFirst)];
    }
    if (!_searched) {
      return [_notice(BusStrings.searchPrompt)];
    }
    final stopFailure = _stopFailure;
    if (stopFailure != null) {
      return [_notice(_failureMessage(stopFailure), onRetry: _search)];
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

  /// 키 문제와 그 밖의 장애를 갈라 말한다 — 확인 시트와 같은 문구를 쓴다.
  /// 사용자가 읽는 사실이 같은데 문구를 따로 만들면 둘 중 하나만 손보게 된다.
  String _failureMessage(TagoOutcome outcome) =>
      outcome == TagoOutcome.keyError
          ? BusStrings.emptyKey
          : BusStrings.emptyDown;

  Widget _notice(String message, {VoidCallback? onRetry}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing24,
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.sub,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSizes.spacing8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: Text(
                BusStrings.emptyDownAction,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
