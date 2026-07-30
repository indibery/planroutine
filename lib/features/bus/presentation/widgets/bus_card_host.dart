import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../data/bus_api_client.dart';
import '../../domain/bus_card_view.dart';
import '../../domain/bus_display.dart';
import '../../domain/bus_poll_interval.dart';
import '../../domain/bus_settings.dart';
import '../../domain/bus_stop.dart';
import '../../domain/commute_direction.dart';
import '../providers/bus_providers.dart';
import 'bus_arrival_card.dart';

/// 점을 움직이는 주기. **네트워크와 무관하다** — `buildBusCardView`가 `now`를 받는
/// 순수 함수라, 리빌드만 시키면 경과 보정이 다시 돌아 점이 초만큼 왼쪽으로 간다.
///
/// `BusBodyAxis.tick`과 **같은 값이어야** 애니메이션이 끊기지 않는다.
const busMoveInterval = Duration(seconds: 1);

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

  /// 점을 움직이는 1초 틱. 폴링(`_timer`)과 같은 조건에서 같이 살고 죽는다.
  Timer? _moveTimer;
  BusFetch? _fetch;

  /// 방향 토글은 **화면 수명**이다 — 저장하지 않는다.
  CommuteDirection? _flipped;

  /// `다시 시도`로 시작한 조회가 비행 중인가.
  ///
  /// **이 가드는 재시도 버튼에만 걸린다.** `_tick` 전체에 in-flight 가드를 두는
  /// 안(모든 촉발에 거는 전역 가드)은 Task 14에서 기각됐다 — 비행 중에 도착한
  /// 폴링·복귀·슬롯 교체 tick을 버리면 방향 전환이 최대 30초 빈 카드로 남는다.
  /// 재시도 버튼은 그 사유가 성립하지 않는다: `down`/`stale`+빈 목록 상태라
  /// **가려질 콘텐츠가 애초에 없다**(빈 카드로 남을 목록 자체가 없다).
  bool _retrying = false;

  /// 눌렀다는 것이 **보이게** 진행 표시를 최소 시간 유지한다.
  ///
  /// 캐시가 신선하면(`busCacheTtl` 30초 안) `_tick`이 네트워크 없이 즉시 끝나 진행
  /// 표시가 한 프레임만 돌고 사라진다 — 눌렀는데 아무 일도 없는 것처럼 보이고,
  /// 사용자는 다시 누른다.
  static const _minRefreshFeedback = Duration(milliseconds: 350);

  /// **손으로** 새로고침을 누른 시각. 쿨다운 판정의 기준이다.
  ///
  /// 자동 폴링은 이 값을 건드리지 않는다 — 폴링까지 쿨다운을 걸면 30초 주기가 곧
  /// 쿨다운이라 아이콘이 늘 흐려 보인다. 막으려는 것은 사람의 연속 탭이다
  /// (실기기 신고 2026-07-29: "장난으로 누를 수도 있는데 연속해서 못 누르게").
  DateTime? _manualRefreshAt;

  /// 쿨다운이 끝나는 순간 한 번 리빌드한다 — 없으면 다음 폴링(최대 30초 뒤)까지
  /// 아이콘이 흐린 채로 남는다.
  Timer? _cooldownTimer;

  /// 지금 손으로 누를 수 있는가.
  ///
  /// 쿨다운을 `busCacheTtl`과 같게 둔다 — 그 안에 다시 눌러도 캐시가 답해 새 값이
  /// 오지 않으므로, 누를 수 있게 두면 "반응 없는 버튼"이 된다. 즉 이 쿨다운은
  /// 새로 만든 제약이 아니라 **이미 있던 사실을 화면에 드러내는 것**이다.
  bool get _canRefresh {
    final at = _manualRefreshAt;
    return at == null || _now().difference(at) >= busCacheTtl;
  }

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
    _moveTimer?.cancel();
    _cooldownTimer?.cancel();
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
      // 백그라운드에서 초당 리빌드를 남기지 않는다.
      _moveTimer?.cancel();
      _moveTimer = null;
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

  /// `다시 시도` 탭. 비행 중이면 두 번째 탭을 버리고, 그동안 진행 문구를 띄운다.
  ///
  /// 없으면 탭한 뒤 최대 10초(`_get`의 timeout) 동안 화면이 **전혀** 바뀌지 않는다 —
  /// `_tick`은 fetch 앞에서 setState를 하지 않고(이 상태의 `fetchedAt`은 null이라
  /// 표시 드롭 분기도 건너뛴다) 스피너도 없다. 그래서 사용자는 다시 누르고,
  /// 실패 결과는 `_fallback`이 캐시에 쓰지 않으므로 매 탭이 캐시 미스가 되어
  /// **탭 N번 = 동시 HTTP 요청 N건**이 된다. 키는 IPA에 하나뿐이라 개발계정
  /// 10,000/일 한도를 전 사용자가 공유한다(스펙 §5의 호출 회계).
  ///
  /// 제목줄 새로고침도 **같은 함수**를 쓴다 — 촉발 경로가 갈리면 이 가드가 한쪽에만
  /// 남는다.
  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _manualRefreshAt = _now();
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(busCacheTtl, () {
      if (mounted) setState(() {});
    });
    final started = _now();
    try {
      await _tick();
    } finally {
      final elapsed = _now().difference(started);
      if (elapsed < _minRefreshFeedback) {
        await Future<void>.delayed(_minRefreshFeedback - elapsed);
      }
      // 화면이 사라진 뒤 setState를 부르면 던진다 — 응답이 10초 뒤에 올 수 있다.
      if (mounted) setState(() => _retrying = false);
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
      _moveTimer?.cancel();
      _moveTimer = null;
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
    // **다음 간격을 매번 다시 계산한다.** `Timer.periodic`이 아닌 이유는 간격이
    // 고정이 아니기 때문이다 — 지금 뜬 버스가 지나가는 시점을 겨냥하므로 매 조회
    // 결과에 따라 달라진다(`busPollIntervalFor`).
    //
    // 늘 취소 후 재설정한다. `??=`는 periodic 시절 중복 생성을 막던 관용구인데,
    // 일회성 `Timer`에 그대로 쓰면 **이미 만료된 핸들이 non-null로 남아 다음
    // 예약이 통째로 건너뛰어진다** — 폴링이 한 번 돌고 영영 멈춘다.
    final next = busPollIntervalFor(_viewOf(fetch, stop));
    _timer?.cancel();
    _timer = next == null ? null : Timer(next, _tick);

    // 이동 틱 — 조회하지 않고 리빌드만 한다.
    //
    // 폴링이 멈춰도(막차 뒤) 이 틱은 남긴다. 리빌드뿐이라 비용이 없고, 그 리빌드가
    // `_display`를 새 `now`로 돌려 **시간대 만료를 1초 안에** 반영한다. 그때
    // `!shouldPoll`이 참이 되는데 `_tick`이 다시 돌지 않으므로, 정리는 이 틱이 직접
    // 한다 — 안 그러면 접힌 뒤에도 1초 타이머가 무기한 남는다.
    _moveTimer ??= Timer.periodic(busMoveInterval, (_) {
      if (!mounted) return;
      if (!_shouldPoll()) {
        _moveTimer?.cancel();
        _moveTimer = null;
        _timer?.cancel();
        _timer = null;
      }
      setState(() {});
    });
  }

  /// 조회·이동 틱이 함께 쓰는 조건. 셋 중 하나라도 어긋나면 둘 다 멈춘다.
  bool _shouldPoll() {
    final settings = ref.read(busSettingsProvider).valueOrNull;
    if (settings == null) return false;
    final display = _display(settings);
    return settings.enabled &&
        settings.stopFor(display.direction) != null &&
        display.expanded;
  }

  /// 화면이 그리는 것과 **같은** view. `build`와 `_tick`이 각자 조립하면 간격이
  /// 사용자가 보는 목록과 어긋난다(상한 `1차+30초`가 성립하는 전제가 깨진다).
  BusCardView _viewOf(BusFetch fetch, BusStop stop) => buildBusCardView(
        state: fetch.state,
        arrivals: fetch.arrivals,
        fetchedAt: fetch.fetchedAt,
        now: _now(),
        routeIds: stop.routeIds,
      );

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
        // **`onRetry`를 넘기지 않는다.** 이 분기는 `state: ok` + 빈 목록이고
        // `BusEmptyState`의 ok 튜플은 action이 null이라 재시도 줄이 아예 그려지지
        // 않는다 — 도달하지 않는 콜백이다. 형태를 맞추려고 남겨두면 재시도 경로가
        // 두 개(여기 `_tick`, 아래 `_retry`)로 갈려 어느 쪽이 in-flight 가드를
        // 지나는지 읽어서는 알 수 없게 된다.
      );
    }

    final view = _viewOf(fetch, stop);

    return BusArrivalCard(
      view: view,
      style: settings.style,
      direction: display.direction,
      stopName: stop.nodeNm,
      expanded: display.expanded,
      onToggleExpanded: () => _toggleExpanded(display),
      onFlipDirection: _flip,
      // 재시도가 실제로 도달하는 유일한 경로다(`stale`·`down` + 빈 목록).
      // `_tick`이 아니라 `_retry`를 넘긴다 — 가드와 진행 문구가 거기 있다.
      onRetry: _retry,
      // **같은 함수를 넘긴다.** 제목줄 새로고침과 빈 상태의 재시도가 하는 일이 같고,
      // 촉발 경로가 갈리면 in-flight 가드가 한쪽에만 남는다.
      //
      // 스로틀은 따로 두지 않는다 — `BusApiClient`의 30초 캐시가 그 역할을 한다.
      // 신선한 동안 눌러도 네트워크 요청이 나가지 않고 같은 목록이 돌아오며,
      // 제목줄의 `07:32 기준`이 그대로인 것이 "방금 받은 것"이라는 표시다.
      onRefresh: _retry,
      retrying: _retrying,
      refreshEnabled: _canRefresh,
      // **`onRegister`를 넘기지 않는다.** 여기 `view.state`는 `fetch.state`에서
      // 오고 `BusApiClient`가 낼 수 있는 값은 ok·closed·stale·down·keyError
      // 다섯뿐이다(`noStop`을 만드는 곳은 위 분기 하나뿐이고 소비처도
      // `BusEmptyState`의 noStop 분기뿐이다) — 도달하지 않는 콜백이다.
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
