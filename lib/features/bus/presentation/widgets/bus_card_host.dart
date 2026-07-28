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
    // **촉발점은 이 리스너 하나다.**
    //
    // 여기서 `_tick()`을 직접 부르면 안 된다 — 그 시점 busSettingsProvider는 아직
    // AsyncLoading이라 settings == null로 즉시 return하고, 설정이 도착해도 다시
    // 부르는 곳이 없어 **첫 조회가 영구히 나가지 않는다**(cold mount).
    //
    // 그렇다고 `build`의 `ref.listen`에 맡기면 반대편이 죽는다 — `ref.listen`은
    // **변화만** 받는다(riverpod 2.6.1은 `fireImmediately`를 지원하지 않는다,
    // `consumer.dart:604`의 주석). `busSettingsProvider`는 autoDispose가 아니라
    // 아무도 invalidate하지 않으므로, 설정 탭에서 켜고 오늘 탭으로 오거나 탭을
    // 왕복하면(이 앱은 `ShellRoute`라 화면이 dispose된다) **이미 AsyncData인
    // provider 위에서 마운트돼 리스너가 한 번도 울지 않는다** → 카드가 영구 로딩
    // (warm mount). 타이머도 성공한 tick 뒤에만 생기므로(`_timer ??=`) 30초 폴링조차
    // 시작되지 않는다.
    //
    // `listenManual`은 `fireImmediately`를 지원하고(`consumer.dart:98-103`) State
    // 수명에 맞춰 자동 해제된다. cold는 `settings == null`로 조용히 지나가고 warm은
    // 즉시 첫 조회를 띄운다 — 두 경로가 한 촉발점으로 모인다.
    ref.listenManual<AsyncValue<BusSettings>>(
      busSettingsProvider,
      _onSettings,
      fireImmediately: true,
    );
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

  /// 설정이 도착하거나 바뀔 때의 촉발 — 로딩 완료·스위치 ON·슬롯 교체·시간대
  /// 변경이 모두 여기로 들어온다. `initState`의 `listenManual`이 부른다.
  void _onSettings(AsyncValue<BusSettings>? prev, AsyncValue<BusSettings> next) {
    final before = prev?.valueOrNull;
    final after = next.valueOrNull;
    if (after == null) return;

    // 정류장이 바뀌었으면 옛 목록을 즉시 버린다. 남기면 제목줄은 새 정류장인데
    // 본문은 옛 정류장의 도착 목록인 상태가 남는다 — 펼침이면 최대 30초, 접힘이면
    // 타이머가 없어 무기한이다(CLAUDE.md의 push 함정이 여기 성립한다).
    final beforeId = before?.stopFor(_display(before).direction)?.nodeId;
    final afterId = after.stopFor(_display(after).direction)?.nodeId;
    if (beforeId != afterId) _fetch = null;

    // **`_tick()`은 마이크로태스크로 미룬다.** `fireImmediately`가 이 콜백을
    // `initState` 안에서 **동기적으로** 부르는데, `_tick`은 첫 await 전에
    // `setState`(묵은 결과 드롭)를 할 수 있어 프레임을 만드는 도중에 걸린다.
    // 미루면 그 동기 호출 스택이 끝난 뒤에 돈다. 그 사이 화면이 사라질 수 있으므로
    // `mounted`로 막는다 — `_tick`의 `ref.read`는 dispose 뒤에 부르면 던진다.
    Future.microtask(() {
      if (mounted) _tick();
    });
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
      // **화면도 정리한다.** 타이머만 끊고 돌아가면 카드를 리빌드시키는 신호가
      // 없어(설정은 안 바뀌고 `today_screen`이 watch하는 provider 셋은 주기 신호가
      // 아니다) 마지막 프레임이 그대로 남는다 — 시간대가 끝났는데 카드는 여전히
      // 펼쳐진 채 `720번 2분`을 보여주고 그 값은 다시 계산되지 않는다(리뷰 재현:
      // 08:31로 밀어도 `list=1 stamp=1`). 펼치기 override 만료도 같은 경로다.
      //
      // 여기서 `_fetch`를 비우면 리빌드가 돌아 `_display`가 새 `now`로 접힘을
      // 반환하고 묵은 목록도 사라진다. 본문은 `expanded`로만 게이트되므로
      // (`bus_arrival_card.dart`의 `if (expanded)`) 접힌 카드에 로딩 문구가
      // 노출되지는 않는다.
      if (mounted && _fetch != null) setState(() => _fetch = null);
      return;
    }

    // 묵은 결과는 그리지 않는다 — 복귀 직후 한 프레임이라도 40분 전 목록을 `ok`로
    // 그리면 이미 지나간 버스가 `곧`으로 표시된다(경과 보정이 arrMin을 0으로 깎지만
    // 목록이 비지 않아 state는 ok로 남는다). 조회 전 경로가 emptyLoading을 그리는
    // 것과 같은 논리다.
    //
    // 기준은 `busMaxDisplayAge`(3분)다 — **`busCacheTtl`(30초)이면 안 된다.**
    // `fetchedAt`은 요청 **시작** 시각인데 폴링 타이머는 응답이 돌아온 뒤에 걸려
    // 다음 tick이 `T+d+30초`에 오므로, TTL을 기준으로 쓰면 `d+30 > 30`이 구조적으로
    // 항상 참이 되어 **정상 폴링마다** 목록과 기준시각이 사라지고 로딩 문구가 떴다
    // (실패 구간에서는 stale의 fetchedAt이 항상 옛 시각이라 확정적으로 매 tick).
    // 경과 보정이 수십 초 오차를 이미 흡수하므로 30초 초과로 목록을 버릴 이유가 없다.
    final last = _fetch?.fetchedAt;
    if (last != null && _now().difference(last) > busMaxDisplayAge) {
      setState(() => _fetch = null);
    }

    final fetch = await ref
        .read(busApiClientProvider)
        .fetchArrivals(cityCode: stop.cityCode, nodeId: stop.nodeId);
    if (!mounted) return;
    setState(() => _fetch = fetch);

    // 조건 5를 여기서도 본다 — 비행 중에 앱이 내려가면 응답이 돌아와 타이머를
    // 백그라운드에서 새로 걸어버린다(라이프사이클 콜백은 이미 지나갔다).
    //
    // **`== resumed`가 아니라 배경 상태를 열거해 막는다.** `lifecycleState`는
    // nullable이고 바인딩이 첫 라이프사이클 메시지를 받기 전에는 null이다
    // (`SchedulerBinding.resetInternalState`가 테스트마다 null로 돌린다) — `!= resumed`로
    // 쓰면 그 null까지 배경으로 취급해 **위젯 테스트에서는 타이머가 아예 걸리지 않는다**
    // (실측: `30초마다 다시 조회한다`가 count 1로 실패). 실제 누수는 `paused`·`detached`가
    // 종착 배경 상태라 이 형태로도 막힌다 — `inactive`·`hidden`을 지나 내려가는 경우는
    // 뒤따라 오는 `didChangeAppLifecycleState`의 else 분기가 타이머를 끊는다.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      return;
    }
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
    // `initState`의 리스너(`_onSettings`)가 이미 조회를 띄운다 — 한 번 더 부르면 펼치기
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
    // **여기에 `ref.listen`을 두지 않는다.** 촉발은 `initState`의 `listenManual`
    // 하나가 맡는다 — 둘 다 두면 설정을 바꿀 때마다 두 번 촉발돼 펼치기 탭마다
    // TAGO 요청이 2건 나간다(30초 캐시는 **완료된** 응답만 담아 비행 중인 첫
    // 요청이 두 번째를 흡수하지 못한다).
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
        // **접을 수 없는 카드다.** 빈 콜백을 넘기면 눌러도 아무 일이 없는 chevron이
        // 그려지고 스크린리더가 `접기`라고 읽는다 — 기능을 켠 사용자가 가장 먼저
        // 보는 화면에서 죽은 컨트롤이 된다.
        onToggleExpanded: null,
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
