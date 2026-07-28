import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../data/bus_api_client.dart';
import '../../domain/bus_card_view.dart';
import '../../domain/bus_display.dart';
import '../../domain/bus_settings.dart';
import '../../domain/commute_direction.dart';
import '../providers/bus_providers.dart';
import 'bus_arrival_card.dart';

/// 폴링 주기. 서버 캐시가 없으니 이 값이 곧 호출 주기다.
const busPollInterval = Duration(seconds: 30);

/// 오늘 탭 최상단에 카드를 얹는 호스트.
///
/// **요청이 나가는 조건 여섯 개를 이 한곳에서 판정한다**(스펙 §6). 조건을 여러 곳에
/// 흩어 놓으면 촉발 지점을 추가할 때 한쪽을 빠뜨려 새는 구멍이 생긴다.
///
/// 1) 표시 ON  2) 그 방향 슬롯 있음  3) 펼침  4) 이 위젯이 마운트됨
/// 5) 포그라운드  6) 캐시 미스([BusApiClient]가 판정)
class BusCardHost extends ConsumerStatefulWidget {
  const BusCardHost({super.key, this.clock});

  /// 테스트가 시각을 고정하기 위한 주입점.
  final DateTime Function()? clock;

  @override
  ConsumerState<BusCardHost> createState() => _BusCardHostState();
}

class _BusCardHostState extends ConsumerState<BusCardHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  BusFetch? _fetch;

  /// 방향 토글은 **화면 수명**이다 — 저장하지 않는다.
  CommuteDirection? _flipped;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 여기서 _tick()을 부르면 안 된다 — 그 시점 busSettingsProvider는 아직
    // AsyncLoading이라 settings == null로 즉시 return하고, 설정이 도착해도 다시
    // 부르는 곳이 없어 **첫 조회가 영구히 나가지 않는다.** 타이머도 성공한 tick
    // 뒤에만 생기므로(`_timer ??=`) 30초 폴링조차 시작되지 않는다.
    // 촉발은 build의 ref.listen이 맡는다(아래).
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 복귀 시 즉시 1회 — **단 여섯 조건을 통과할 때만.** 접힌 채 복귀하면
      // 화면은 아무것도 안 바뀌는데 조회가 나가는, 눈에 안 보이는 구멍이 된다.
      _tick();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// 조건을 통과하면 조회하고 타이머를 유지한다. 아니면 타이머를 끈다.
  Future<void> _tick() async {
    final settings = ref.read(busSettingsProvider).valueOrNull;
    if (settings == null) return;

    final display = _display(settings);
    final stop = settings.stopFor(display.direction);

    final shouldPoll = settings.enabled && stop != null && display.expanded;
    if (!shouldPoll) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    final fetch = await ref
        .read(busApiClientProvider)
        .fetchArrivals(cityCode: stop.cityCode, nodeId: stop.nodeId);
    if (!mounted) return;
    setState(() => _fetch = fetch);

    _timer ??= Timer.periodic(busPollInterval, (_) => _tick());
  }

  /// 시간대 판정 + 화면 수명 방향 토글.
  BusDisplay _display(BusSettings settings) {
    final resolved = resolveBusDisplay(now: _now(), settings: settings);
    final direction = _flipped ?? resolved.direction;
    return BusDisplay(direction: direction, expanded: resolved.expanded);
  }

  Future<void> _toggleExpanded(BusDisplay display) async {
    final notifier = ref.read(busSettingsProvider.notifier);
    final settings = ref.read(busSettingsProvider).valueOrNull;
    if (settings == null) return;

    final wantExpanded = !display.expanded;
    final byRange = resolveBusDisplay(
      now: _now(),
      settings: settings.clearOverride(),
    ).expanded;

    // override는 항상 "시간대 판정의 반대"만 담는다. 같은 방향이면 저장할 이유가
    // 없어 지운다 — 상태가 스스로 정리된다.
    if (wantExpanded == byRange) {
      await notifier.clearOverride();
    } else {
      await notifier.setOverride(expanded: wantExpanded, at: _now());
    }

    // **여기서 `_tick()`을 부르지 않는다.** 위 두 저장이 모두 설정을 바꾸므로
    // `build`의 `ref.listen`이 이미 조회를 띄운다 — 여기서 한 번 더 부르면 펼치기
    // 탭마다 TAGO 요청이 **2건** 나간다(`_save`가 prefs 저장 전에 동기적으로
    // `state = AsyncData(next)`를 하고, 30초 캐시는 **완료된** 응답만 담아 비행 중인
    // 첫 요청이 두 번째를 흡수하지 못한다).
    //
    // 반대로 `_flip`은 설정을 건드리지 않고 `_flipped`만 바꾸므로 리스너가 울지
    // 않는다 — 그래서 거기서는 `_tick()`을 직접 부른다. 촉발의 규칙은 하나다:
    // **설정을 저장하면 리스너에 맡기고, 로컬 상태만 바꾸면 직접 부른다.**
  }

  @override
  Widget build(BuildContext context) {
    // 설정이 도착하거나 바뀔 때가 유일한 최초 촉발점이다 — 로딩 완료·스위치 ON·
    // 슬롯 교체·시간대 변경이 모두 여기로 들어온다. initState에서 부르면 그때는
    // 아직 AsyncLoading이라 아무 일도 일어나지 않는다.
    ref.listen<AsyncValue<BusSettings>>(busSettingsProvider, (prev, next) {
      final before = prev?.valueOrNull;
      final after = next.valueOrNull;
      if (after == null) return;

      // 정류장이 바뀌었으면 옛 목록을 즉시 버린다. 남기면 제목줄은 새 정류장인데
      // 본문은 옛 정류장의 도착 목록인 상태가 남는다 — 펼침이면 최대 30초, 접힘이면
      // 타이머가 없어 무기한이다(CLAUDE.md의 push 함정이 여기 성립한다).
      final beforeId = before?.stopFor(_display(before).direction)?.nodeId;
      final afterId = after.stopFor(_display(after).direction)?.nodeId;
      if (beforeId != afterId) _fetch = null;

      _tick();
    });

    final settings = ref.watch(busSettingsProvider).valueOrNull;
    if (settings == null || !settings.enabled) return const SizedBox.shrink();

    final display = _display(settings);
    final stop = settings.stopFor(display.direction);

    if (stop == null) {
      return BusArrivalCard(
        view: const BusCardView(
          state: BusCardState.noStop,
          visible: [],
          hiddenCount: 0,
          fetchedAt: null,
        ),
        style: settings.style,
        direction: display.direction,
        stopName: '',
        expanded: true,
        onToggleExpanded: () {},
        onFlipDirection: _flip,
        // **`?slot=`을 반드시 붙인다.** 검색 화면은 쿼리가 없으면 출근 슬롯으로
        // 조용히 떨어지므로, 퇴근 카드에서 등록하면 학교 앞 정류장이 출발지에
        // 저장된다 — 화면은 여전히 `정류장을 등록하면…`이라 저장 실패로 읽히고,
        // 다음 아침 출근 카드에 학교 앞 정류장이 뜬다. 원인이 쿼리 한 개라
        // 추적이 어렵다. 방향은 지금 손에 들고 있다(`display.direction`).
        onRegister: () =>
            context.push('${AppRoutes.busStops}?slot=${display.direction.name}'),
      );
    }

    final fetch = _fetch;

    // 조회 전(`_fetch == null`)을 `ok` + 빈 목록으로 넘기면 buildBusCardView가 그
    // 조합을 `closed`로 바꿔 **아직 아무것도 조회하지 않았는데 "오늘 운행이
    // 끝났어요"** 를 낸다. 스펙 §3이 막차 종료와 장애를 뭉개지 말라고 한 그 지점이다.
    // buildBusCardView의 `ok + 빈 = closed` 규칙은 실제 응답에 대한 계약이므로
    // 건드리지 않고, 조회 전에는 그 함수를 부르지 않는다.
    if (fetch == null) {
      return BusArrivalCard(
        view: BusCardView(
          state: BusCardState.ok,
          visible: const [],
          hiddenCount: 0,
          fetchedAt: null,
        ),
        style: settings.style,
        direction: display.direction,
        stopName: stop.nodeNm,
        expanded: display.expanded,
        onToggleExpanded: () => _toggleExpanded(display),
        onFlipDirection: _flip,
        onRetry: _tick,
      );
    }

    final view = buildBusCardView(
      state: fetch.state,
      arrivals: fetch.arrivals,
      fetchedAt: fetch.fetchedAt,
      now: _now(),
      routeIds: stop.routeIds,
    );

    return BusArrivalCard(
      view: view,
      style: settings.style,
      direction: display.direction,
      stopName: stop.nodeNm,
      expanded: display.expanded,
      onToggleExpanded: () => _toggleExpanded(display),
      onFlipDirection: _flip,
      onRetry: _tick,
      // 위 noStop 분기와 같은 이유로 슬롯을 붙인다. 이 경로의 `onRegister`는
      // `BusEmptyState`가 noStop에서만 쓰므로 실질 도달하지 않지만, 형태가 갈라져
      // 있으면 나중에 도달하게 될 때 조용히 틀린다.
      onRegister: () =>
          context.push('${AppRoutes.busStops}?slot=${display.direction.name}'),
    );
  }

  void _flip() {
    final settings = ref.read(busSettingsProvider).valueOrNull;
    if (settings == null) return;
    setState(() {
      _flipped = _display(settings).direction.flipped;
      _fetch = null;
    });
    _tick();
  }
}
