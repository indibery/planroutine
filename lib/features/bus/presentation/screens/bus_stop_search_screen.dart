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
import '../../domain/stop_search_view.dart';
import '../providers/bus_providers.dart';
import '../widgets/bus_stop_confirm_sheet.dart';

/// 정류장 이름 검색 → 확인 시트 → 슬롯 저장.
///
/// **이름 검색이 주 경로이고 도시 선택은 보조다.** GBIS가 이름만으로 서울·경기·인천을
/// 한 번에 답하므로(실측 `강남역` → 서울 16건) 대부분의 사용자는 도시를 고르지 않는다.
/// 그 밖의 지역(부산·제주 등)만 `다른 지역에서 찾기`로 도시 선택을 펼쳐 TAGO로 찾는다.
///
/// **자동 폴백이 아니라 명시적 전환인 이유**: GBIS가 0건이면 TAGO로 넘기는 규칙은
/// 성립하지 않는다. 부산 사용자가 `서면`을 찾으면 GBIS가 서울·광명·인천의
/// `강서면허시험장` 등 12건을 주므로(실측) 0건이 아니고, 자동 폴백은 영구히 걸리지 않는다.
///
/// 도시 목록(TAGO 138개)은 **필요할 때만** 부른다 — 화면 진입마다 부르면 주 경로가
/// TAGO 응답 속도에 묶인다(실측 5.1s, 클라이언트 타임아웃 10s에 근접).
///
/// GPS 근접 검색을 쓰지 않는다. 슬롯을 **교체**하는 순간(전근·이사)에는 대상
/// 정류장 근처에 없는 것이 기본값이라 GPS가 못 쓰인다 — 이름 검색만 항상 작동한다.
class BusStopSearchScreen extends ConsumerStatefulWidget {
  const BusStopSearchScreen({super.key, this.slot});

  /// 채울 슬롯. `/bus/stops?slot=toWork` 쿼리로 넘어온다.
  final CommuteDirection? slot;

  static const cityFieldKey = Key('bus_city_field');
  static const stopFieldKey = Key('bus_stop_field');

  /// `다른 지역에서 찾기` — 도시 선택을 펼친다. 라벨로 찾으면 안내 문구와 링크가
  /// 같은 낱말을 쓰게 되므로 키로 찾는다.
  static const otherRegionKey = Key('bus_other_region');

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

  /// 검색 결과에서 고른 지역. null이면 전체.
  ///
  /// **도시 선택(`_city`)과 다른 것이다.** 이건 이미 받은 결과를 세어 만든 칩이고
  /// 추가 조회가 없다. 이름 검색 결과가 감당이 안 되기 때문에 있다(실측 `시청` 160곳,
  /// `아파트` 4,366곳) — 사용자가 지역으로 좁히거나 정류소번호를 넣어야 한다.
  String? _region;

  /// 두 글자 미만으로 검색을 눌렀는가.
  ///
  /// GBIS가 1글자를 `resultCode 22`로 거부한다. 화면이 먼저 막는다 — 헛요청이 없고,
  /// 서버 오류로 말하면 사용자가 재시도만 반복한다(재시도해도 같다).
  bool _tooShort = false;

  /// 도시 선택을 펼쳤는가 — **켜져 있으면 TAGO로 찾는다.**
  ///
  /// 화면 수명 동안만 유지한다(저장하지 않는다). 다음에 정류장을 고칠 때 다시 수도권
  /// 검색부터 시작하는 것이 맞다 — 지역을 바꾸는 일이 정류장을 바꾸는 일보다 드물다.
  bool _regionMode = false;

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

  /// 지금 검색을 보낼 수 있는가. 수도권 검색은 도시가 필요 없다.
  bool get _canSearch => !_regionMode || _city != null;

  @override
  void dispose() {
    _cityFilter.dispose();
    _stopQuery.dispose();
    super.dispose();
  }

  /// 도시 선택을 펼친다 — 이때 처음 도시 목록을 부른다.
  void _enableRegionMode() {
    setState(() {
      _regionMode = true;
      // 수도권 검색 결과를 남겨두면 도시를 고르기 전까지 그것이 이 모드의 결과처럼
      // 읽힌다(도시별 결과와 섞인다).
      _results = const [];
      _searched = false;
      _stopFailure = null;
    });
    if (_cities.isEmpty) _loadCities();
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
      // 못 고르면 이 모드에서 할 수 있는 일이 없으므로 ok가 아닌 모든 결과를
      // 실패로 말하고 재시도를 준다(TAGO는 정상이면 전국 138개를 준다).
      _cityFailure = result.outcome == TagoOutcome.ok ? null : result.outcome;
      // **편집 중인 슬롯의** 도시를 먼저, 없으면 반대 슬롯 — 두 슬롯이 다 등록된
      // 뒤 도착지를 고치는데 출발지의 도시가 복원되면, 잘못된 cityCode는 오류가
      // 아니라 빈 응답으로 와서 `검색 결과가 없어요` 한 번을 헛치게 된다.
      //
      // GBIS로 저장한 정류장은 cityCode가 0이라 일치하는 도시가 없어 자연히
      // 복원되지 않는다 — 그 정류장은 애초에 도시로 찾은 것이 아니다.
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

  /// 이름 또는 정류소번호로 찾는다 — 모드에 따라 소스가 갈린다.
  Future<void> _search() async {
    final name = _stopQuery.text.trim();
    final city = _city;
    // 도시를 고르지 않은 지역 모드에서는 돋보기가 비활성이고 화면이 `먼저 도시를
    // 골라주세요`를 띄우므로, 여기서 조용히 return해도 사용자는 이유를 읽는다.
    if (name.isEmpty || !_canSearch) return;

    // GBIS는 1글자를 거부한다(`resultCode 22`). 보내지 않고 여기서 말한다.
    if (name.length < 2) {
      setState(() {
        _tooShort = true;
        _results = const [];
        _searched = false;
        _stopFailure = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _tooShort = false;
      _stopFailure = null;
      // 새 검색이면 옛 지역 필터를 버린다 — 안 버리면 `서울`을 고른 채 다른 이름을
      // 찾아 결과가 0건인데 이유가 화면에 없다.
      _region = null;
    });
    final client = ref.read(busApiClientProvider);
    final result = _regionMode && city != null
        ? await client.searchStops(cityCode: city.code, name: name)
        : await client.searchGbisStops(name: name);
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

  /// 정류장을 탭했을 때 — 바로 저장하지 않고 노선 목록과 오는 버스를 조회해 확인받는다.
  ///
  /// 두 조회를 **함께 보낸다.** 순차로 보내면 시트가 뜨기까지 왕복이 두 번이라 느린
  /// 회선에서 탭이 먹지 않은 것처럼 느껴진다. 둘 다 예외를 던지지 않고 실패를
  /// outcome으로 돌려주므로(경유노선이 실패하면 도착정보 기반 목록으로 폴백) 한쪽
  /// 실패가 다른 쪽을 막지 않는다.
  Future<void> _pick(BusStop stop) async {
    setState(() => _loading = true);
    final client = ref.read(busApiClientProvider);
    final (routes, fetch) = await (
      client.fetchViaRoutes(nodeId: stop.nodeId),
      client.fetchArrivals(cityCode: stop.cityCode, nodeId: stop.nodeId),
    ).wait;
    if (!mounted) return;
    setState(() => _loading = false);

    final confirmed = await BusStopConfirmSheet.show(
      context,
      stop: stop,
      // 선택 목록의 주 재료. 비면 시트가 도착정보로 목록을 만든다 — 비수도권
      // 정류장(부산·제주)과 경유노선 조회 실패가 그 경로다.
      routes: routes.items,
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
          // **이름 칸이 첫 컨트롤이다.** 도시 선택이 위에 있으면 대부분의 사용자가
          // 필요 없는 단계를 먼저 만난다.
          _stopSearchField(),
          if (_regionMode) ...[
            const Divider(height: 1),
            _cityPicker(),
          ],
          const Divider(height: 1),
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
            // 지역 모드에서 도시를 고르기 전에는 조회가 나갈 수 없다 — 활성처럼
            // 보이면 눌러도 아무 일이 없는 죽은 컨트롤이 된다. 수도권 검색은
            // 도시가 필요 없으므로 기본 상태에서는 항상 활성이다.
            onPressed: _canSearch ? _search : null,
          ),
        ),
        onSubmitted: (_) => _search(),
      ),
    );
  }

  /// 도시코드는 시·군 단위로 전국 138개다 — 스크롤만으로 고르게 하면 마찰이 크므로
  /// 검색 필드를 둔다. **지역 모드에서만 그린다.**
  Widget _cityPicker() {
    final cities = _cityFilter.text.trim().isEmpty
        ? _cities
        : _cities
            .where((c) => c.name.contains(_cityFilter.text.trim()))
            .toList();

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

  List<Widget> _resultRows() {
    // 순서가 계약이다: 못 물어본 것 → 고를 수 없는 것 → 아직 안 찾은 것 →
    // 찾았지만 실패 → 정말 없음. 뒤섞으면 각 문구가 다른 상황을 덮는다.
    final cityFailure = _cityFailure;
    if (_regionMode && cityFailure != null) {
      return [_notice(_failureMessage(cityFailure), onRetry: _loadCities)];
    }
    if (!_canSearch) {
      return [_notice(BusStrings.cityFirst)];
    }
    if (_tooShort) {
      return [_notice(BusStrings.searchTooShort)];
    }
    if (!_searched) {
      return [
        _notice(BusStrings.searchPrompt),
        // **검색 전에도 지역 전환이 보여야 한다.** 결과가 나온 뒤에만 두면 부산
        // 사용자는 수도권 결과가 나올 헛검색을 한 번 해야 여기 도달한다.
        if (!_regionMode) ...[
          _hint(BusStrings.searchCapitalHint),
          _otherRegionLink(),
        ],
      ];
    }
    final stopFailure = _stopFailure;
    if (stopFailure != null) {
      return [_notice(_failureMessage(stopFailure), onRetry: _search)];
    }
    if (_results.isEmpty) {
      return [
        _notice(BusStrings.searchEmpty),
        // 수도권 밖을 찾는 사람이 여기 도달한다 — 그때만 지역 전환을 권한다.
        if (!_regionMode) ...[
          _hint(BusStrings.searchOtherRegionHint),
          _otherRegionLink(),
        ],
      ];
    }

    final view = buildStopSearchView(stops: _results, region: _region);

    return [
      // 지역 칩이 목록 **위**에 온다 — 아래 두면 잘린 목록을 다 훑은 뒤에야 좁히는
      // 수단을 만난다.
      if (view.hasRegionChoice) _regionChips(view),
      if (view.truncated) ...[
        _notice(BusStrings.searchTooMany(view.total)),
        _hint(BusStrings.searchTooManyHint),
      ],
      ...view.visible.map((stop) => ListTile(
            title: Text(stop.nodeNm),
            // **지역명이 여기 있어야 한다.** 도시를 먼저 고르지 않으므로 화면
            // 어디에도 지역 정보가 없고, 같은 이름의 정류장이 여러 시·군에 있다
            // (실측 `A정류장` → 경기 3개 시·인천). 도시 선택 단계가 조용히
            // 제공하던 정보를 결과 행으로 옮긴 것이다.
            subtitle: Text(_subtitleOf(stop)),
            trailing: Icon(Icons.chevron_right, color: AppColors.faint),
            onTap: () => _pick(stop),
          )),
      // 결과가 있어도 남긴다 — 이름이 겹쳐 수도권 결과만 나오는 경우
      // (실측 `서면` → 부산 없이 12건) 여기가 유일한 출구다.
      if (!_regionMode) _otherRegionLink(),
    ];
  }

  /// 검색 결과에서 뽑은 지역 칩. **추가 조회가 없다** — 받은 결과를 세기만 한다.
  Widget _regionChips(StopSearchView view) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing8,
      ),
      child: Wrap(
        spacing: AppSizes.spacing8,
        runSpacing: AppSizes.spacing4,
        children: [
          PillChip(
            label: BusStrings.regionAll,
            selected: _region == null,
            onTap: () => setState(() => _region = null),
          ),
          ...view.regions.map((r) => PillChip(
                label: BusStrings.regionChip(r.name, r.count),
                selected: r.name == _region,
                onTap: () => setState(() => _region = r.name),
              )),
        ],
      ),
    );
  }

  /// 정류소번호와 (있으면) 지역명.
  String _subtitleOf(BusStop stop) {
    final region = stop.regionName;
    return region == null
        ? '${stop.nodeNo}'
        : BusStrings.stopRegion(region, stop.nodeNo);
  }

  Widget _otherRegionLink() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing24),
      child: Center(
        child: GestureDetector(
          key: BusStopSearchScreen.otherRegionKey,
          behavior: HitTestBehavior.opaque,
          onTap: _enableRegionMode,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spacing8),
            child: Text(
              BusStrings.searchOtherRegion,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 키 문제와 그 밖의 장애를 갈라 말한다 — 확인 시트와 같은 문구를 쓴다.
  /// 사용자가 읽는 사실이 같은데 문구를 따로 만들면 둘 중 하나만 손보게 된다.
  String _failureMessage(TagoOutcome outcome) =>
      outcome == TagoOutcome.keyError
          ? BusStrings.emptyKey
          : BusStrings.emptyDown;

  /// 안내 문구 아래 붙는 한 줄. 본문보다 작고 조용하다.
  Widget _hint(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          color: AppColors.faint,
        ),
      ),
    );
  }

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
