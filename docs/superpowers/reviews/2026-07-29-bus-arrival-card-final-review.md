# 버스 도착 카드 — 병합 전 최종 리뷰

- 대상: `feat/bus-arrival-card`의 버스 작업 범위(코드 40파일 + 문서 2파일)
- 코드 diff: `.superpowers/sdd/2026-07-28-bus-arrival-card/final-code.diff`
- 문서 diff: `.superpowers/sdd/2026-07-28-bus-arrival-card/final-docs.diff`
- 기준 상태: 618 테스트 통과 · `flutter analyze` 깨끗
- 6개 관점이 각각 반증 시도를 통과한 49건을 종합해 **43건**으로 정리했다(6건은 중복 병합).

**판정: 이대로 병합하면 안 된다.** blocking 1건(B1)이 기능을 실사용 경로에서 무력화한다. B1 + I1~I4(신뢰를 깨는 4건)를 고치고 시뮬레이터로 한 번 밟은 뒤 병합할 것. 자세한 판정은 맨 아래.

| 구획 | 건수 |
|---|---|
| 🔴 병합 차단(blocking) | 1 |
| 🟠 병합 전 권장(important) | 16 |
| 🟡 출하 후(minor) | 26 |

## 이 리뷰에서 직접 실행해 재현한 것

읽기 전용 원칙을 지켜 리포를 건드리지 않고, 스크래치패드의 테스트 파일을 `flutter test`로 돌렸다.

| 대상 | 명령 결과 | 결론 |
|---|---|---|
| B1 (warm mount) | `WARM MOUNT requestCount=0 loading=1 list=0` / `AFTER 62s requestCount=0` | 재현 — 첫 조회도, 폴링도 나가지 않는다 |
| I2 (시간대 종료) | `BEFORE list=1 count=1` → 08:31로 밀고 pump(30초) → `RANGE END list=1 stamp=1 count=1` | 재현 — 목록·기준시각이 얼어붙고 요청은 늘지 않는다 |

그 밖에 코드로 직접 확인한 것: `flutter_riverpod` 2.6.1 `consumer.dart:604`의 `We can't implement a fireImmediately flag` 주석과 `WidgetRef.listen`의 파라미터 부재(`listenManual`만 `:640`에서 받는다) · `bus_body_axis.dart`의 `hiddenCount` 참조 0회 · `app_reset_repository.dart:13`이 DB 3테이블만 지우는 것 · `bus_arrival_card.dart:64-78`이 본문을 `expanded`로만 게이트하는 것(I2 수정의 안전성 근거) · 죽은 심볼 5개(`rangeFor`·`BusStrings.lowFloor`·`prevCnt`·`isOk`·`usesSignalColors`)의 참조 위치 · `privacy_policy.md`와 `ios/fastlane/Fastfile`의 줄번호.

---

# 🔴 구획 A. 병합 차단 (1건)

## B1. 오늘 탭 재진입·설정에서 켠 뒤 첫 진입에서 카드가 영구 로딩이 된다

> 종합: `logic-1`(correctness, CONFIRMED) + 지연 백로그의 신규 필수 항목(동일 결함)

**위치**: `lib/features/bus/presentation/widgets/bus_card_host.dart:169-182`(유일한 촉발점) · `:46-55`(initState가 의도적으로 `_tick`을 안 부름) · `:124`(`_timer ??=`) · `:221-237`(로딩 분기)

**실패 시나리오** (두 경로 모두 실사용의 대부분이다)

1. **설정에서 켠 직후**: 설정 탭에서 `표시`를 켜고 정류장을 등록하면 그 시점에 `busSettingsProvider`가 `AsyncData`가 된다. 오늘 탭으로 이동하면 `BusCardHost`는 **이미 data인 provider** 위에서 마운트되는데 `ref.listen`은 등록 직후 발화하지 않는다.
2. **탭 왕복**: 오늘 → 캘린더 → 오늘. `app_router.dart:56-104`가 `StatefulShellRoute`가 아닌 평범한 `ShellRoute` + `NoTransitionPage`이고 `main_shell.dart:56`이 `context.go`로 페이지를 교체하므로 `TodayScreen`(과 그 안의 `BusCardHost`)이 dispose·재생성된다. 그런데 `busSettingsProvider`는 autoDispose가 아니라(`bus_providers.dart:22-25`) 아무도 invalidate하지 않아 data를 유지한다 → 다시 warm mount.

두 경우 모두 `initState`가 `_tick()`을 부르지 않고(`:50-55`, Task 14가 cold mount의 영구 로딩을 고치려 옮긴 조치) 타이머는 성공한 tick 뒤에만 생기므로(`_timer ??=`, `:124`) **`_tick()`이 한 번도 불리지 않는다** → `_fetch == null` 분기(`:221`)가 `도착시간을 확인하고 있어요`를 무기한 그리고 30초 폴링도 시작되지 않는다. `ok` 상태에는 `다시 시도`가 없어(`bus_empty_state.dart:35`의 ok 튜플이 `action = null`이고 `:82`가 `if (action != null)`로 게이트) 화면상 복구 수단도 없다. 복구 경로는 제목줄 2탭(접기→펼치기, 각각 설정 저장) 또는 앱 백그라운드→복귀뿐이다.

**근거**: flutter_riverpod 2.6.1 `consumer.dart:604`에 `We can't implement a fireImmediately flag` 주석이 그대로 있고 `WidgetRef.listen`에 그 파라미터가 없다(`listenManual`만 `:640`에서 받는다). 이 리뷰에서 warm mount를 실행 재현했다: `requestCount=0 loading=1 list=0`, 시계를 31초씩 두 번 밀어도 `requestCount=0`(폴링 타이머조차 안 걸린다).

**왜 blocking인가**: 기능을 켠 직후와 탭 왕복 후가 실사용의 대부분인데 그 경로에서 카드가 죽는다. 문구가 "확인하고 있어요"라 사용자는 로딩으로 읽고 계속 기다리지만 조회는 영원히 나가지 않는다. Task 14가 cold mount를 고치면서 warm mount가 반대편에 새로 생긴 형태다.

**고칠 방법** (권장 = a)

```dart
// initState 안 (bus_card_host.dart:47-55)
ref.listenManual<AsyncValue<BusSettings>>(
  busSettingsProvider,
  _onSettings,          // build의 ref.listen 콜백을 메서드로 추출해 공유
  fireImmediately: true, // ← cold(AsyncLoading)는 settings==null로 조용히 return,
                         //    warm(AsyncData)은 즉시 첫 조회를 띄운다
);
```

`listenManual`은 `fireImmediately`를 지원하고(`consumer.dart:98-103`) State 수명에 맞춰 자동 해제된다. `build`의 `ref.listen`은 제거한다(중복 촉발 방지). 대안 (b): `build`에 `bool _kicked` 가드 + `WidgetsBinding.instance.addPostFrameCallback((_) => _tick())`.

**가드 테스트**(현재 픽스처에 이 경로가 없다 — `bus_card_host_test.dart`의 `_pumpHost`는 항상 새 `ProviderScope`에서 `AsyncLoading`부터 출발해 리스너가 반드시 한 번 발화한다):

```dart
// 같은 컨테이너를 먼저 warm 시킨 뒤 마운트한다
final container = ProviderContainer(overrides: [busApiClientProvider.overrideWithValue(client)]);
await container.read(busSettingsProvider.future);          // = 설정 탭 상당
await tester.pumpWidget(UncontrolledProviderScope(container: container, child: ...));
await tester.pumpAndSettle();
expect(count, 1, reason: '이미 data인 설정 위에서 마운트해도 첫 조회는 나간다');
```

---

# 🟠 구획 B. 병합 전 권장 (16건)

순서는 사용자 영향 × 고치는 비용. I1~I4는 **거짓 정보를 자신 있게 말하는** 부류라 최상단에 둔다.

## I1. stale 폴백에 나이 상한이 없어 수십 분 묵은 목록이 전부 `곧 도착`으로 표시된다

> 종합: `logic-4` + `user-triple-truth-2` + `test-guarantees-1` (세 관점이 같은 결함을 가리킴)

**위치**: `lib/features/bus/data/bus_api_client.dart:169-178`(`_fallback`, 나이 검사 없음) · `:110`·`:117`(캐시는 성공 응답에서만 갱신) · `lib/features/bus/domain/bus_card_view.dart:77-82`(경과 보정 후 0으로 clamp) · `lib/features/bus/presentation/widgets/bus_body_text.dart:63-64`(0분 → `곧 도착`)

**실패 시나리오**: 07:32에 `720번 4분`을 받아 캐시가 채워진 뒤 통신이 끊긴다(터널·지하·기지국 장애·TAGO 5xx). 실패 경로는 캐시 엔트리를 갱신하지도 삭제하지도 않으므로 이후 모든 조회가 `_fallback`을 타 `stale` + `fetchedAt: 07:32`을 계속 돌려준다. 08:10에 `buildBusCardView`가 elapsed 2280초를 차감해 arrMin을 0으로 깎고 `BusBodyText`가 0분을 `곧 도착`으로 18px·w800·ink로 렌더한다 → **38분 전에 이미 지나간 버스가 `720번 곧 도착`으로 뜬다.** 반증 단서는 헤더 10px `07:32 기준 · 갱신 실패` 하나뿐이다.

**세 관점이 각각 더한 것**
- 도달 경로가 폴링 10분 유지보다 넓다: `busApiClientProvider`가 autoDispose가 아니라(`bus_providers.dart:15-19`) 캐시가 **앱 프로세스 수명만큼** 살아 있고, 오늘 탭은 탭 이동 시 dispose되므로 "한 시간 뒤 네트워크 없이 오늘 탭 재진입" 한 번만으로도 재현된다.
- 캐시는 프로세스 수명 동안 절대 만료·축출되지 않으므로, 앱이 살아 있는 상태로 **다음 날 아침** 조회가 실패하면 어제 07:32 목록이 뜬다 — 스탬프가 `hh:mm`뿐이라 날짜 차이를 드러내지도 못한다.
- 테스트에 반증 재료가 0이다: `bus_api_client_test.dart:127-142`가 시계를 **31초만** 밀어 arrMin 4가 4로 나오는 무해한 구간만 검사하고, host 테스트의 `MockClient`는 전부 200을 돌려줘 stale 렌더 경로가 아예 없다.

**스펙과의 관계**: 스펙 §3(402행)은 `stale = 캐시 목록 + 갱신 실패`만 정하고 나이 상한을 두지 않는다 — 즉 이것은 구현의 이탈이 아니라 **스펙에 있던 빈칸**이다. 그러나 §2가 경과 보정을 넣은 이유("실시간인 척하면 버스를 놓친 사용자가 앱을 불신한다")를 정면으로 배반하는 방향으로 작동하므로 스펙 쪽을 고쳐야 한다.

**고칠 방법**: 표시 나이 상한 상수 하나를 두고 원천에서 자른다(I3와 같은 상수를 공유해 두 곳이 어긋나지 않게 한다).

```dart
// bus_api_client.dart
/// 이 나이를 넘긴 캐시는 stale로도 쓰지 않는다 — 경과 보정이 전부 `곧 도착`으로 깎는다.
const busMaxDisplayAge = Duration(minutes: 3);

BusFetch _fallback(String key, _CacheEntry? cached, BusCardState failure) {
  if (cached == null ||
      cached.arrivals.isEmpty ||
      _now().difference(cached.fetchedAt) > busMaxDisplayAge) {
    _cache.remove(key);
    return BusFetch(state: failure, arrivals: const [], fetchedAt: null);
  }
  ...
}
```

호출부 4곳(`:125`·`:128`·`:132`)에 `key`를 넘기도록 시그니처를 한 줄 확장한다. **가드 테스트**: 성공 1회 → 시계를 40분 전진 → 실패 → `expect(r.state, BusCardState.down)` + `expect(r.fetchedAt, isNull)`(상한을 지우면 반드시 실패한다). 기존 31초 stale 테스트는 그대로 둔다.

## I2. 시간대 종료·펼치기 override 만료가 화면을 갱신하지 않아 카드가 펼친 채 옛 도착 분으로 얼어붙는다

> `logic-2` (correctness, CONFIRMED) — 이 리뷰에서 재실행 재현

**위치**: `lib/features/bus/presentation/widgets/bus_card_host.dart:84-89`

**실패 시나리오**: 오늘 탭을 켜둔 채 08:30을 넘긴다. 08:30:20 tick이 목록을 그린 뒤 다음 타이머 tick에서 `display.expanded`가 false가 되어 `shouldPoll`이 거짓 → `_timer`만 끊고 **setState 없이 return**한다. `BusCardHost`를 리빌드시키는 다른 신호가 없으므로(설정 변화 없음, `today_screen.dart`는 `todayViewProvider`·`todayReferenceProvider`·`stampSettingsProvider`만 watch하고 셋 다 주기 신호가 아니다) 화면은 마지막 프레임 그대로 남는다 — 카드는 여전히 펼쳐져 `720번 2분`을 보여주고 그 값은 다시 계산되지 않는다. 묵은 결과 드롭 가드(`:98-101`)는 이 return **뒤**에 있어 도달하지 않는다. 펼치기 override 만료도 같은 경로다(08:35 펼침 → 09:05 만료 → 타이머만 조용히 끊긴다).

**재현 결과**: 08:29에 조회해 목록을 그린 뒤 08:31로 밀고 `pump(30초)` → `RANGE END list=1 stamp=1 count=1`. 사용자가 오늘 목록을 건드리면 그때 리빌드로 접히지만 그건 우연한 치유다.

**왜 중요한가**: 폴링이 멈춘 카드가 살아 있는 것처럼 옛 도착 분을 계속 보여준다 — 이 카드의 유일한 용도(지금 나갈지 판단)에서 가장 위험한 실패다. 스펙 §6이 "9시~16시는 이미 접힘이므로 별도 설정이 필요 없다"고 한 자동 접힘이 표시에서 성립하지 않는다.

**고칠 방법**: `!shouldPoll` 분기에서 화면도 정리한다(`bus_card_host.dart:85-89`).

```dart
if (!shouldPoll) {
  _timer?.cancel();
  _timer = null;
  // 화면도 접는다 — 안 하면 펼친 카드가 마지막 프레임에 얼어붙는다.
  if (mounted && _fetch != null) setState(() => _fetch = null);
  return;
}
```

리빌드가 돌면 `_display`가 새 `now`로 접힘을 반환해 카드가 접히고 묵은 목록도 사라진다. **본문은 `expanded`로만 게이트되므로**(`bus_arrival_card.dart:64-78` 확인) 접힌 카드에 로딩 문구가 노출되는 부작용은 없다. **가드 테스트**: 가변 clock으로 08:29 pump(목록 확인) → 08:31로 밀고 `pump(busPollInterval)` → `expect(find.text('720번'), findsNothing)`.

## I3. 표시 드롭 임계값이 캐시 TTL과 같아 정상 폴링마다 목록이 사라지고 로딩 문구가 뜬다

> `logic-3` (correctness, CONFIRMED)

**위치**: `lib/features/bus/presentation/widgets/bus_card_host.dart:98-101` (`busCacheTtl`: `bus_api_client.dart:17` = 30s, `busPollInterval`: `bus_card_host.dart:17` = 30s)

**실패 시나리오**: 첫 조회의 `fetchedAt`은 요청 **시작** 시각 T인데(`bus_api_client.dart:83`의 `now`가 `:192` await 전에 캡처됨) 폴링 타이머는 응답이 돌아온 **T+d**에 생성된다(`:124`가 await 뒤). 따라서 첫 폴링 tick은 T+d+30s에 발화하고 드롭 조건 `> busCacheTtl`은 `d+30s > 30s`라 **구조적으로 항상 참**이다 → `setState(() => _fetch = null)` → 그 프레임에서 목록과 `07:32 기준`이 사라지고 `도착시간을 확인하고 있어요`만 남는다. 재현: 두 번째 요청만 `Completer`로 붙잡아 `MID-POLL list=0 loading=1 requestCount=2`.

정상망에서 보이는 시간은 왕복 1회(수백 ms)라 체감이 작지만, **실패 구간에서는 확정적이다** — 통신이 끊기면 stale의 `fetchedAt`이 항상 옛 시각이라 매 tick 드롭이 확정이고, 타임아웃 10초 동안 목록 대신 로딩 문구가 떠 스펙 §3이 약속한 "캐시 목록 + 갱신 실패" 유지가 30초마다 깨진다.

**왜 중요한가**: 두 임계값(클라이언트 캐시 TTL과 표시 드롭)을 같은 값으로 둔 탓에 "정상 주기"가 항상 경계를 넘는다 — 주석이 의도한 "창을 넘긴 값만 화면에서 내린다"가 성립하지 않는다.

**고칠 방법**: 드롭 기준을 폴링 주기와 분리한다. `bus_card_host.dart:99`의 `busCacheTtl`을 **I1에서 만든 `busMaxDisplayAge`(3분)** 로 바꾼다. 경과 보정이 이미 수십 초 오차를 흡수하므로 30초 초과만으로 목록을 버릴 이유가 없다. 상수 하나로 I1의 stale 상한과 I3의 표시 드롭을 함께 정의하면 두 곳이 어긋나지 않는다.

## I4. 노선 필터가 걸린 채 그 노선만 안 오면 카드가 "오늘 운행이 끝났어요"라고 단정한다 (다른 버스는 오고 있다)

> `user-visible-truth-1` (product-behavior, CONFIRMED)

**위치**: `lib/features/bus/domain/bus_card_view.dart:100-102` · `lib/features/bus/presentation/widgets/bus_empty_state.dart:36` · `test/features/bus/domain/bus_card_view_test.dart:67`

**실패 시나리오**: 확인 시트에서 92번만 남긴 사용자. 07:30에 정류장에는 82-1번이 8분 뒤 온다(TAGO 정상 응답, resultCode 00, 항목 1건). `buildBusCardView`가 routeIds 필터로 82-1을 걸러 `limited`가 비고, `limited.isEmpty && state == ok` → `closed`로 승격한다. `BusEmptyState`가 closed를 `emptyClosed`로 매핑해 화면에는 평일 아침 07:30에 **"오늘 운행이 끝났어요"** 가 뜬다.

**왜 중요한가**: 스펙 §3이 "신뢰의 급소"라 부른 지점 그대로다 — "막차 끝남"과 "내 노선만 안 옴"은 정류장에서 기다릴지 다른 수단을 찾을지를 가르는 정반대의 정보인데 같은 문구로 뭉개졌다. enum 주석(`bus_card_view.dart:25`)은 스스로 두 뜻을 겸한다고 인정하는데 화면 문구는 한쪽만 말한다. 더 나쁜 것은 테스트 이름(`골라둔 노선이 지금 안 오면 운행 종료로 읽힌다`)이 이 동작을 정답으로 고정해 나중에 아무도 회귀로 보지 않는다. routeIds를 고르는 것은 확인 시트의 정상 경로다.

**고칠 방법**: `closed`를 두 갈래로 쪼갠다 — `buildBusCardView`는 판단 재료를 이미 갖고 있다.

```dart
// bus_card_view.dart:100 부근
final resolved = switch (state) {
  BusCardState.ok when limited.isEmpty && routeIds.isNotEmpty && arrivals.isNotEmpty
      => BusCardState.filteredOut,          // 새 상태
  BusCardState.ok when limited.isEmpty => BusCardState.closed,
  _ => state,
};
```

`BusStrings`에 `emptyFiltered = '고른 노선은 지금 오지 않아요'`(+ 선택 변경 유도 힌트)를 추가하고 `BusEmptyState`의 switch에 **이름으로** 넣는다(와일드카드 금지 계약 유지 — `bus_empty_state.dart:26`의 주석이 그 이유를 적었다). 테스트 이름·단정도 새 상태로 고친다.

## I5. `시간 축` 모양은 `hiddenCount`를 아예 그리지 않아 5노선 중 2개를 조용히 버린다

> 종합: `user-visible-truth-3` + `logic-6`의 축 부분

**위치**: `lib/features/bus/presentation/widgets/bus_body_axis.dart` 전체(`hiddenCount` 참조 **0회** — grep으로 확인) · 대비: `bus_body_text.dart:31-40`

**실패 시나리오**: 실측 정류장(수원시청, 노선 5개)을 등록하고 확인 시트에서 전부 체크 → 스펙대로 `routeIds = {}`(필터 없음)로 저장된다(`bus_stop_search_screen.dart:335-336` — **확인 시트의 기본 저장값**이라 예외 설정이 아니라 다수 경로다). `설정 > 카드 모양`을 `시간 축`으로 바꾼다. `buildBusCardView`가 앞 3개만 남기고 `hiddenCount = 2`를 채우지만 `BusBodyAxis`는 `view.visible`만 순회한다. 화면에는 점 3개와 노선번호 3개만 남고 `2개 더`가 없다 — 사용자는 이 정류장에 버스가 3대만 온다고 읽는다. 자기 노선이 4·5번째(예: 61번 31분)면 "내 버스는 안 오네"로 결론 낸다.

**왜 중요한가**: 스펙 §1의 표(`비어 있음(전부) → 가장 빠른 3개 + N개 더 한 줄`, 145행)와 "두 모양은 실패 계약·접기·시간대를 전부 공유한다. 다른 것은 본문 렌더뿐이다"(213행 인근)를 동시에 어긴다. `간단히`에는 있는 표시가 `시간 축`에만 없어 모양을 바꾼 사용자만 조용히 손해를 본다. 위젯 테스트(`bus_body_test.dart:84-91`)는 눈금·노선번호 존재만 검사해 이 공백을 못 잡는다(`N개 더` 테스트는 `BusBodyText` 그룹에만 있다).

**고칠 방법**: `BusBodyAxis`의 `_labels()` 아래(또는 라벨 행 우측 정렬)에 `if (view.hiddenCount > 0) Text(BusStrings.moreCount(view.hiddenCount))`를 넣는다. 축 오른쪽 끝은 이미 `15분` 눈금이 있으므로 라벨 행 우측이 안전하다. 겸해서 `모양을 바꿔도 같은 정보가 보인다`를 검사하는 위젯 테스트를 추가한다 — 두 모양이 공유해야 하는 것 목록에 `hiddenCount`가 빠져 있었다. (표기를 링크처럼 보이게 할지는 M2와 같은 결정을 따를 것.)

## I6. 첫 등록에서 도시를 고르지 않고 검색하면 아무 일도 일어나지 않고, 화면은 "정류장 이름을 입력해 주세요"라고 계속 말한다

> `user-visible-truth-4` (product-behavior, CONFIRMED)

**위치**: `lib/features/bus/presentation/screens/bus_stop_search_screen.dart:73-76`(`_search`) · `:58-71`(`_loadCities`) · `:219-232`(`_resultRows`)

**실패 시나리오**: 기능을 처음 켠 사용자가 `정류장 등록`으로 들어온다. `_loadCities`가 도시를 받아 칩을 그리지만 저장된 정류장이 없으므로 `_city`는 **null**이다(`:69` `matched.isEmpty ? null : ...`). 사용자가 `시청`을 치고 돋보기를 누르면 `_search()`의 `if (city == null || name.isEmpty) return;`이 **setState도, 문구도, 스낵바도 없이** 즉시 반환한다. `_searched`가 false로 남아 화면에는 여전히 `정류장 이름을 입력해 주세요`가 떠 있다 — 이름을 방금 입력한 사용자에게 이름을 입력하라고 말한다. 몇 번 더 눌러도 반응이 0이다.

**왜 중요한가**: 기능을 켠 직후 사용자가 반드시 지나는 **유일한 등록 경로**에서 검색 버튼이 죽은 컨트롤이 된다. 도시 칩을 먼저 탭해야 한다는 요구가 화면 어디에도 없고(라벨은 `도시` 한 단어) 실패 신호도 없어 사용자는 앱이 고장 났다고 판단하고 등록을 포기한다. 원장의 "`_search`/`_loadCities`가 outcome을 버려 조회 실패가 `검색 결과가 없어요`로 표시된다"와는 **다른 증상**이다 — 여기서는 조회 자체가 시작되지 않아 어떤 문구도 갱신되지 않는다. `bus_stop_search_test.dart`는 전부 `BusStopConfirmSheet`만 다뤄 이 경로는 무가드다.

**고칠 방법**: `_city == null`이면 검색 어포던스를 죽인다 — suffixIcon의 `onPressed`를 null로 내리고(비활성 색으로 보인다), `_resultRows`의 첫 분기에 `_notice(BusStrings.cityFirst)`(신설: `먼저 도시를 골라주세요`)를 넣는다. 도시 목록 조회가 실패해 칩이 0개인 경우(`_city`가 null이 되는 두 번째 경로)는 `_loadCities`의 `result.outcome`을 살려 별 문구 + 재시도를 준다.

## I7. 검색 화면·확인 시트가 어느 슬롯에 저장하는지 한 번도 말하지 않는다 — 일과시간에 카드에서 등록하면 도착지에 들어간다

> `user-visible-truth-5` (product-behavior, CONFIRMED)

**위치**: `lib/features/bus/presentation/screens/bus_stop_search_screen.dart:126`(AppBar title) · `:350`(확인 시트 제목) · `:111`(저장) · 대비: `lib/features/settings/presentation/widgets/bus_settings_tiles.dart:56,64`

**실패 시나리오**: 10:20에 `설정 > 버스 도착 > 표시`를 켜고 오늘 탭으로 간다. `_nextDirection`이 `620분 < toHomeRange.start(960분)`이라 **toHome**을 고르므로 카드 제목줄은 `🏫→🏠 퇴근 ·`이고 본문은 `정류장을 등록하면 도착시간이 보여요`다. `정류장 등록`을 누르면 `?slot=toHome`으로 검색 화면이 열리는데(Task 13이 이 쿼리를 고쳤다 — 저장 자체는 올바르다), AppBar 제목은 `정류장 찾기`뿐이고 확인 시트 제목도 `이 정류장이 맞나요?`뿐이라 **어느 슬롯을 채우는지 어디에도 없다**. 집 앞 정류장을 골라 `맞아요`를 누르면 도착지 슬롯에 저장되고 화면은 조용히 pop된다. 다음 아침 출근 카드는 다시 `정류장을 등록하면…`이고 퇴근 카드에 집 앞 정류장이 앉아 있다. 기본 시간대에서 이 분기가 잡히는 구간은 **08:31–15:59** — 교사가 설정을 만지는 가장 흔한 시간대다.

**왜 중요한가**: 슬롯 두 개가 이 기능의 전체 데이터 모델인데 쓰기 대상이 시계로 자동 결정되고 그 결정이 표시되지 않는다. 스펙 §4가 확인 시트를 만든 이유는 "방향이 조용히 틀리는 것을 막는다"인데, 시트는 nodeId 방향(상행/하행)만 확인시키고 **슬롯 방향(출발지/도착지)은 확인시키지 않는다**. 설정 탭 경로(`출발지`/`도착지` 타일을 직접 탭)에서는 사용자가 아는데 카드 경로에서는 알 방법이 없다 — 두 경로의 정보 비대칭이다.

**고칠 방법**: `BusStopSearchScreen`이 `slot`을 화면에 드러낸다. AppBar 제목을 슬롯 이름에서 조립하거나(`'${슬롯라벨} 정류장 찾기'`, 문구는 `BusStrings`에 추가), 최소한 확인 시트 제목 아래에 `출발지에 저장합니다` 한 줄을 넣는다. 슬롯이 쿼리에서 오지 않은 폴백(`widget.slot ?? toWork`)일 때도 같은 문구가 나와야 라우트를 손으로 열었을 때의 결과가 보인다.

## I8. "전체 데이터 초기화"가 정류장 설정을 지우지 않아 처리방침의 삭제 약속과 확인 다이얼로그 문구가 함께 깨진다

> `secrets-privacy-deploy-2` (privacy-deploy, CONFIRMED)

**위치**: `lib/features/settings/data/app_reset_repository.dart:13` · `lib/features/bus/presentation/providers/bus_providers.dart:13`(`bus_settings_v1`) · `docs/privacy_policy.md:37-38`·`:105-106`

**실패 시나리오**: 출발지·도착지 정류장을 등록한 뒤 설정 → 데이터 관리 → "전체 데이터 초기화"를 실행한다. `AppResetRepository.resetAll()`은 `_dbHelper.resetAllData()` **한 줄뿐이므로**(직접 읽어 확인) `shared_preferences`의 `bus_settings_v1`(정류장 ID·이름·번호·도시코드·선택 노선·시간대)이 그대로 남는다 → 초기화 직후에도 오늘 탭 카드가 같은 정류장을 계속 보여준다. 스위치를 꺼도 값은 저장돼 있고 슬롯을 비우는 UI도 없어(원장의 지연 항목: `copyWith` null 병합) **앱 삭제 외에 지우는 경로가 없다.**

**왜 중요한가**: 이 기능이 새로 저장하는 값은 '집 근처에서 타는 정류장'과 '학교 근처에서 타는 정류장'이다 — 대략적 거주지와 근무지를 함께 드러내는, 이 앱이 지금까지 저장한 어떤 값보다 민감한 조합이다. 공개 호스팅된 처리방침 §4("'전체 데이터 초기화'를 실행할 때까지 보관")·§7("일괄 삭제 가능")이 지울 수 있다고 약속하는데 지워지지 않는다. 더 직접적인 것은 `SettingsStrings.resetAllConfirmMessage`가 "모든 데이터가 영구 삭제됩니다"라고 절대적으로 단정한다는 점이다.

**고칠 방법** (둘 중 하나, 코드 쪽이 정직하다)
1. `resetAll()`이 `SharedPreferences`의 `bus_settings_v1`도 지운다(도장·알림 키까지 함께 지울지는 별 판단 — 설정과 데이터의 경계를 어디로 둘지 사용자에게 물을 것).
2. 코드를 안 고치면 처방침 §4를 "설정(알림·도장·정류장)은 앱을 삭제할 때까지 보관됩니다"로 정정하고 §7의 "일괄 삭제" 범위를 일정·이벤트로 한정하고, 확인 다이얼로그 문구도 함께 좁힌다.

## I9. TAGO 키가 빌드 후 리포 안 두 파일에 남고, 빌드 로그로 나간다 — Fastfile 주석의 보장과 어긋난다

> `secrets-privacy-deploy-1` (privacy-deploy, CONFIRMED)

**위치**: `ios/fastlane/Fastfile:313-331`(특히 주석 `:314-319`) · `ios/Flutter/Generated.xcconfig`(0644) · `ios/Flutter/flutter_export_environment.sh`(0755)

**실패 시나리오**: `./ios/bin/fastlane.sh beta`를 돌린다. tmp json은 `Dir.mktmpdir` 블록이 끝나며 지워지지만, flutter는 모든 dart-define을 base64 CSV로 `Generated.xcconfig`와 `flutter_export_environment.sh`에 **다시 쓴다**(flutter_tools `ios/xcode_build_settings.dart:248` + `build_info.dart:344`의 `toEnvironmentConfig` — 두 파일이 같은 `DART_DEFINES` 리스트를 공유한다). 지금 이 리포의 두 파일이 그것을 증명한다(`DART_DEFINES=RkxVVFRFUl9WRVJTSU9OPTMuNDEuNg==,…`) — 거기에 `TAGO_KEY=<64자>` 항목이 하나 더 붙는다. 이 파일들은 다음 `flutter clean`(= 다음 beta의 `reset_ios_caches`)까지 world-readable로 남는다.

둘째 경로가 원 발견보다 넓다: `ios/Runner.xcodeproj/project.pbxproj:291-292,308-309`의 CocoaPods 스크립트 페이즈는 `showEnvVarsInLog=0`을 명시하는데 **Flutter 자체의 Run Script 페이즈(`:327-341`)에는 그 설정이 없다** → 기본값(1)이 적용돼 페이즈 실행 전에 Xcode가 `DART_DEFINES`를 포함한 전체 환경변수를 빌드 로그에 찍는다(실측: `~/Library/Logs/gym/Runner-Runner.log:2682,3636`의 `export DART_DEFINES\=…`). 즉 **성공 빌드에서도** 노출되고, 빌드 실패 시에는 flutter가 xcodebuild stdout 전문을 콘솔에 덤프한다(`flutter_tools/src/ios/mac.dart:1238-1241`).

**왜 중요한가**: `Fastfile:314-319` 주석이 "파일 경로만 넘기면 echo·에러 양쪽에서 키가 사라진다", "리포 밖 시스템 임시 디렉터리(0700)에 만들고 블록이 끝나면 지워진다"고 보장하는데, 실제로는 키가 리포 안 world-readable 파일 2개로 되돌아오고 로그에도 들어간다 — 0700 tmpdir의 보호가 하류에서 무의미해진다. 이 리포는 public이라 폴더 압축·백업·에이전트 grep·실수로 `git add -f` 하는 순간이 곧 공개 유출이다. blocking으로 올리지 않는 이유는 두 파일이 gitignore되어 있고(`ios/.gitignore:23,28`) 개발계정 키가 무료·즉시 재발급이라 실제 피해가 제한적이기 때문이다.

**고칠 방법**
1. 빌드 `sh(...)` 직후: `sh("rm", "-f", "ios/Flutter/Generated.xcconfig", "ios/Flutter/flutter_export_environment.sh")`(다음 flutter 명령이 어차피 재생성한다).
2. 주석(`:314-319`)을 실제로 남는 지점을 적는 문장으로 정정 — "echo에서는 사라지지만 `Generated.xcconfig`·`flutter_export_environment.sh`에 base64로 재기록되고 Xcode 스크립트 페이즈가 환경변수를 로그에 찍으므로 빌드 후 지운다".
3. 배포 전문 로그를 보관하는 절차에 `DART_DEFINES` 줄 제거를 명시한다.

## I10. 키 가드가 beta 레인 안에만 있어, 리포가 문서화한 수동 빌드 경로가 가드를 통째로 우회한다

> `secrets-privacy-deploy-5` (privacy-deploy, CONFIRMED)

**위치**: `ios/fastlane/Fastfile:302`(`key = tago_key` — beta 레인에만 있음) · `:364~`(release 레인은 키를 보지 않음) · `CLAUDE.md:484`(수동 폴백) · `CLAUDE.md:481`(altool) · `docs/release_checklist.md:108`

**실패 시나리오**: 함정 #6(시뮬 슬라이스)이 레인 밖에서 재현되면 `CLAUDE.md:484`가 지시하는 수동 폴백 `flutter clean && rm -rf ios/Pods ios/Podfile.lock ios/build && flutter build ipa`를 쓴다. 이 명령에는 `--dart-define-from-file`도 `--dart-define=TAGO_KEY=...`도 없으므로 `String.fromEnvironment('TAGO_KEY')`가 빈 문자열인 IPA가 나온다 → `hasKey == false`(`bus_api_client.dart:72`) → 카드가 영구히 `버스 정보를 불러올 수 없어요`만 띄운다. 그 IPA를 `CLAUDE.md:481`의 altool로 올리고 `release build:<N>`으로 승격하면 release의 가드(A 버전·B VALID·D 심사단계·E 릴리즈노트) **어디도 키를 보지 않아** 버스 기능이 죽은 빌드가 심사에 올라간다. `release_checklist.md:108`도 출시 **후** 호출량 점검이라 "이 빌드가 키를 갖고 있나"를 확인하지 않는다.

**왜 중요한가**: `Fastfile:8-10`이 가드의 존재 이유로 든 것이 정확히 "키 없이 빌드하면 버스 기능이 조용히 죽은 앱이 스토어에 올라간다"인데, 같은 리포가 문서로 안내하는 우회로가 그 가드를 무력화한다. 화면 문구만으로는 원인을 알 수 없어(사용자에게 키 이야기를 하지 않는 설계) 사후 진단도 어렵다.

**고칠 방법**: `CLAUDE.md:484`의 수동 폴백 명령에 dart-define을 포함시키거나, 그 줄을 **"수동 빌드로는 배포하지 않는다 — 캐시만 비우고 beta 레인으로 빌드"** 로 바꾼다(후자가 안전하다). 겸해서 `release_checklist.md` 관문 3에 "승격 대상 빌드가 beta 레인 산출물인지 확인" 한 줄을 넣는다.

## I11. `다시 시도`에 in-flight 가드·로딩 피드백이 없고 실패는 캐시되지 않아 탭마다 요청이 나간다

> `secrets-privacy-deploy-6` (privacy-deploy, CONFIRMED)

**위치**: `lib/features/bus/presentation/widgets/bus_card_host.dart:235`·`:255`(`onRetry: _tick`) · `:77-124`(`_tick`에 in-flight 플래그 없음, await 전 setState 없음) · `lib/features/bus/presentation/widgets/bus_empty_state.dart:82-95`(disabled 처리 없음) · `lib/features/bus/data/bus_api_client.dart:169-178`(실패를 캐시하지 않음)

**실패 시나리오**: 지하철·터널에서 카드가 `지금 정보를 못 받았어요 · 다시 시도`가 된다. 탭하면 `_tick()`이 최대 10초(`:192` timeout) 대기하는데 그 사이 화면이 **전혀 바뀌지 않는다** — `_tick`은 fetch 앞에서 setState를 하지 않고(`_fetch?.fetchedAt`이 null이라 stale-clear 분기도 건너뛴다) 스피너도 없다. 그래서 사용자는 다시 탭한다. 실패 결과는 `_fallback`이 `_cache`에 쓰지 않으므로 매 탭이 캐시 미스 → **탭 N번 = 동시 비행 HTTP 요청 N건**. 그대로 두어도 `_timer ??= Timer.periodic(30초)`는 실패해도 주기가 그대로라, 기본 출근 창(07:00~08:30)에 오늘 탭을 열어두면 창이 끝날 때까지 2요청/분이 계속 나간다.

**왜 중요한가**: 프록시를 보류한 근거가 호출량 계산이다(스펙 §5: 20 호출/일/명, 개발계정 10,000/일 ÷ 20 = 500명). 키는 IPA에 하나뿐이라 한도를 전 사용자가 공유하는데 실패 경로에는 상한이 전혀 없다. Task 14가 "펼치기 탭마다 요청 2건"을 고칠 값이 있다고 판정한 것과 같은 종류의 회계 구멍이다. (원 발견의 "수십 배로 넘겨 전역 장애" 서술은 과장으로 판정했다 — 근거는 약하다. 그러나 무피드백 재시도 버튼 + 무제한 동시 요청은 실제 결함이다.)

**고칠 방법**: `_BusCardHostState`에 `bool _inFlight`를 두고 true면 `BusEmptyState`에 `onRetry: null`을 넘기거나 문구를 로딩으로 바꾼다. Task 14가 기각한 B안(`_tick` 안에서 조용히 return)과 달리 **이 상태에는 가려질 콘텐츠가 없어** 부작용이 없다(빈 카드로 남을 목록 자체가 없다 — 기각 사유였던 "방향 전환 시 최대 30초 빈 카드"가 여기엔 적용되지 않는다). 연속 실패 시 주기를 늘리는 백오프는 실측 호출량을 본 뒤 판단한다.

## I12. 버스 표시 스위치가 app_theme의 switchTheme을 우회해 다크에서 ON 썸이 트랙과 같은 색이 된다

> `convention-1` (conventions, CONFIRMED)

**위치**: `lib/features/settings/presentation/widgets/bus_settings_tiles.dart:43`

**실패 시나리오**: 다크 팔레트에서 `설정 > 버스 도착 > 표시`를 켠다. `activeThumbColor: AppColors.goldFill`이 다크에서 `Color(0xFFE0B96A)`이고, `app_theme.dart:118`의 `switchTheme.trackColor`(selected) = `AppColors.gold`도 다크에서 **같은 `Color(0xFFE0B96A)`** 다(`app_colors.dart:97`/`:102`). Flutter의 해상 순서는 `_widgetThumbColor`(= `activeThumbColor`) > `switchTheme.thumbColor`(`switch.dart:960-966`)라 테마가 정해둔 navy 썸이 밀려난다. M3 스위치는 `thumbShadow = kElevationToShadow[0]`(빈 리스트)이고 selected `trackOutlineColor`는 transparent이므로 그림자·외곽선 단서가 0 → **ON 상태가 썸 없는 단색 골드 알약**으로 그려진다. 같은 ListView의 형제 스위치(`stamp_settings_tiles.dart`·`notification_settings_tiles.dart`)는 `activeThumbColor`를 주지 않아 navy 썸이 정상으로 보인다 — 설정 탭에 스위치 셋이 있는데 새로 넣은 것만 다르게 보인다. 라이트에서는 `goldFill(#E6B95C) ≠ gold(#9A7415)`라 재현되지 않는다.

**왜 중요한가**: 이 스위치는 기능 전체를 켜는 **유일한 관문**이라 기능을 쓰려는 사람이 반드시 보는 컨트롤이다. 리포는 스위치 색을 `app_theme.dart`의 `switchTheme` 한 곳에 모아 navy 썸/gold 트랙 대비를 맞춰 뒀는데 이 한 줄이 그 이유를 지운다. `bus_settings_tiles_test.dart`에 Color 단정이 0건이라 스위트로도 잡히지 않는다.

**고칠 방법**: `bus_settings_tiles.dart:43`의 `activeThumbColor: AppColors.goldFill,` **한 줄을 삭제**해 전역 `switchTheme`에 맡긴다. 굳이 명시하려면 `AppColors.onGold`(= navy)를 써서 테마와 같은 값으로 둔다. 같은 형태가 `event_edit_dialog.dart:358`(`activeThumbColor: AppColors.gold` — 트랙과 두 팔레트 모두 동일)에도 있으니 함께 볼 것(범위 밖이면 별 항목으로).

## I13. 도시 칩이 공용 PillChip 대신 raw ChoiceChip이라 선택된 도시 이름이 다크에서 안 읽힌다(대비 약 1.10:1)

> `convention-2` (conventions, CONFIRMED)

**위치**: `lib/features/bus/presentation/screens/bus_stop_search_screen.dart:168`

**실패 시나리오**: 다크 팔레트에서 `/bus/stops`를 열어 도시 칩을 고른다. 선택 채움은 `chipDefaults.color`(selected) = `colorScheme.secondaryContainer`인데 `app_theme`의 `ColorScheme`이 그것을 주지 않아 `secondary`로 폴백한다(`color_scheme.dart:1099`) → `AppColors.goldGlow` = #F5D98F. 라벨 색은 `chipTheme.labelStyle ?? chipDefaults.labelStyle`(`chip.dart:1367`) 순서라 `app_theme.dart:125-130`이 설정한 **선택/비선택 구분 없는 상수** `AppColors.sub`(다크 = 0xB3F0EAD9, 크림 70%)가 이긴다 — M3가 selected에 쓰려던 `onSecondaryContainer`는 도달하지 않는다. 결과: #F5D98F 채움 위 합성 #F1E5C3 글씨 = **대비 약 1.10:1**. 체크마크(navy)만 보이고 방금 고른 도시 이름은 사라진다. 라이트에서는 sub(#48566E) on #E6B95C ≈ 4.0:1로 재현되지 않는다.

**왜 중요한가**: 이 화면에서 사용자가 확인해야 하는 두 값 중 하나가 '지금 어느 도시를 보고 있는가'다(`_chipCities`가 선택 칩을 맨 앞으로 끌어올리기까지 하는 이유가 그것이다). 리포는 선택 가능한 칩을 전부 `shared/widgets/pill_chip.dart`의 `PillChip`으로 그리며 선택 시 글씨를 `AppColors.gold`로 뒤집어 이 문제를 이미 해결해 뒀다. **lib 전체에서 `ChoiceChip`은 이 한 곳뿐이다.** 화면을 밟는 테스트가 0이라 회귀 가드도 없다. I6과 같은 화면이므로 함께 손대면 비용이 겹친다.

**고칠 방법**: `ChoiceChip`을 `PillChip(label: c.name, selected: selected, onTap: () => setState(() { _city = c; ... }))`으로 교체한다(체크 아이콘·골드 테두리·선택 시 골드 글씨가 이미 들어 있어 모양도 나머지 칩과 맞는다). M4(칩 전환 시 결과 리셋)를 이 `onTap` 안에서 함께 처리하면 한 번에 닫힌다. `ChoiceChip`을 유지하려면 `labelStyle`을 `WidgetStateProperty`로 주거나 `chipTheme.labelStyle`에 selected 분기를 함께 줘야 한다.

## I14. 새 처리방침 절이 실제 TAGO로 나가는 것보다 좁게 적혀 있다 (검색어·미등록 후보 ID·기기 IP 누락)

> 종합: `secrets-privacy-deploy-3` + `test-guarantees-8`

**위치**: `docs/privacy_policy.md:78-86`(신설 절) · `lib/features/bus/data/bus_api_client.dart:144`·`:158-159` · `lib/features/bus/presentation/screens/bus_stop_search_screen.dart:60`·`:79-81`·`:93-95`

**실패 시나리오**: 문서는 "조회 시점에 **등록한** 정류장 ID와 도시코드가 … 전송됩니다"라고만 말한다. 실제 `/bus/stops` 화면은 (1) 진입 즉시 도시 목록을 조회하고(`screen:60` → `client:158-159`), (2) 사용자가 타이핑한 정류장 이름을 `nodeNm` 쿼리로 **그대로** 보내고(`screen:79-81` → `client:144`의 `{'nodeNm': name}`), (3) **저장 전** 후보 정류장 ID로 도착 조회를 한다(`screen:93-95` — 저장은 그 뒤 확인 시트의 `맞아요`에서 일어난다, `:112`). 즉 사용자가 입력한 문자열(`별망초등학교앞`처럼 동네·학교 이름을 넣기 쉬운 칸)과 등록하지 않은 정류장 ID가 TAGO로 나간다. 문단이 "정류장 설정은 기기 안에만 보관됩니다"로 이어져 독자는 전송이 등록 완료된 ID에 한정된다고 읽는다.

또 설계 스펙 §7(659행)은 "정류장 ID와 **기기 IP**가 data.go.kr에 남는다"고 스스로 적었는데, 처방침에는 IP가 없고 "앱은 이용자를 식별하는 정보를 함께 보내지 않으며"만 있다 — 스펙이 이미 인지한 사실과 문서가 어긋난 상태로 공개된다. **누락의 출처는 구현자가 아니라 스펙 §7(663-665행)이 제안한 문구 자체이므로 스펙도 함께 고칠 것.**

**왜 중요한가**: 이 문서는 GitHub Pages로 공개 호스팅되고 App Store 지원 URL·Google OAuth 동의 화면이 참조한다(문서 1-4행이 그렇게 선언한다). 검색어는 등록된 정류장 ID보다 오히려 거주지 추정에 가까운 정보다.

**고칠 방법**: 해당 절에 두 문장을 더한다.
- `정류장을 찾을 때 입력한 검색어(정류장 이름)와 화면에서 고른 후보 정류장의 ID도 조회에 사용됩니다.`
- `HTTPS 요청이므로 기기의 IP 주소가 TAGO 서버 접속 기록에 남습니다(앱이 별도로 보내는 식별 정보는 없습니다).`

## I15. 처리방침 §1·§2·§5·§6이 갱신되지 않아 문서 대부분이 여전히 "외부 연동은 Google 하나"라고 말하고, 새 절은 번호가 없다

> 종합: `user-visible-truth-10` + `secrets-privacy-deploy-4` + `convention-3` (세 관점 동일 결함)

**위치**: `docs/privacy_policy.md:10`(§1) · `:14-20`(§2 표) · `:45-49`(§5 리드) · `:78`(번호 없는 새 절) · `:93`(§6) · `:120`(개정 이력)

**실패 시나리오**: 심사자·사용자가 문서를 위에서 읽는다.
1. **§1 개요(:10)**: "…외부 서비스(Google Calendar)와 연동합니다" — 외부 서비스를 하나만 열거.
2. **§5 리드(:47-49)**: "본 앱은 개인정보를 제3자에게 제공하지 않습니다. 단, … **Google(Google Calendar API)** 에게 이벤트 정보가 전송됩니다" — 제3자를 Google 하나로 못박는데, 그 **바로 아래 하위 절**(:78-86)이 두 번째 제3자(TAGO)로의 전송을 설명한다. 절이 자기 상위 문단을 반박한다.
3. **§2 표(:14-20)**: 마지막 줄이 `알림 설정 | … | 기기 내 shared_preferences`인데, 같은 `shared_preferences`에 새로 보관되는 정류장 ID·이름·번호·도시코드·선택 노선 줄이 없다. **§2 표는 이 문서가 "무엇이 어디에 저장되는가"를 말하는 유일한 정형 목록**인데 가장 민감한 신규 항목만 빠져 있다.
4. **§6 네트워크 통신(:93)**: "Google Calendar API 통신은 전부 HTTPS"만 남아, 실제로 https로 나가는 TAGO(`bus_api_client.dart:14`, TLSv1.3 실측)가 안전성 조치 목록에서 빠진다.
5. **번호 체계**: 새 절은 형제인 `### 5-1`·`### 5-2`와 달리 번호가 없어(`:78`) §5의 하위 항목인지 새 절인지 알 수 없고, 개정 이력(:120)은 그것을 `§ 버스 도착 정보 조회`라는 번호 없는 참조로 부른다(기존 항목은 `§5-1`·`§5-2`).

**왜 중요한가**: 스펙 §7이 "두 번째 외부 통신 경로"라고 못박은 사실이 문서의 요약 지점에서 부정된다 — 문단을 추가하는 것만으로는 앞 문단의 열거가 거짓이 되는 것을 못 막는다. 개정일도 2026-07-29로 올렸으므로 같은 문서 안의 모순은 실질 위험이다. 병합 후 웹에 올라간 뒤 고치면 개정 이력이 한 줄 더 늘고 심사 중이면 되돌리기가 비싸다.

**고칠 방법** (5개, 전부 문서 수정)
1. `:78`을 `### 5-3. 버스 도착 정보 조회(국토교통부 TAGO)`로 번호를 맞춘다(또는 §5와 분리해 `## 6`으로 올리고 이후 번호를 밀되, 그쪽이 비용이 크다).
2. §5 리드(:47-49)에 TAGO를 함께 열거: `단, … Google … 및 국토교통부 TAGO에게 …`.
3. §1(:10)을 `외부 서비스(Google Calendar, 국토교통부 TAGO)`로 고친다.
4. §2 표에 한 줄 추가: `버스 정류장 설정 | 정류장 ID·이름·번호·도시코드·선택 노선 | 정류장 등록 시 | 기기 내 shared_preferences`.
5. §6 네트워크 통신에 TAGO도 HTTPS(TLSv1.3 실측)임을 한 줄 더하고, 개정 이력(:120)의 참조를 새 절 번호로 바꾼다.

## I16. noStop 카드(기능을 켠 사용자가 가장 먼저 보는 화면)에 결함 2개 — 잘린 제목줄 + 죽은 chevron

> 원장의 지연 항목 2건을 **'출하 가능' → '필수'로 재분류**(오케스트레이터 판정). 첫 화면 + 수정 1~2줄.

**위치**: `lib/features/bus/presentation/widgets/bus_card_host.dart:200`(`stopName: ''`) · `:201-202`(`expanded: true, onToggleExpanded: () {}`) · `lib/features/bus/presentation/widgets/bus_arrival_card.dart:105`(`'· $stopName'`) · `:128-133`(chevron + semanticLabel)

**실패 시나리오 (a) 잘린 제목줄**: noStop 분기가 `stopName: ''`을 그대로 넘기고 `_header()`가 빈 이름이어도 `'· $stopName'`을 무조건 그려(직접 확인) 제목줄이 **`출근   · `** 로 끝난다. 정류장을 등록하기 전, 기능을 켜자마자 보는 첫 카드가 잘린 것처럼 보인다.

**실패 시나리오 (b) 죽은 chevron**: noStop 카드가 `expanded: true` + **빈 콜백**을 넘기는데 `_header()` 전체가 `GestureDetector`이고 `Icons.expand_less` + `semanticLabel: BusStrings.collapse`(`접기`)를 그린다 → 스크린리더가 `접기`라고 읽고 탭해도 아무 일이 일어나지 않는다. 원장이 지적한 `N개 더`(M2)와 같은 계열의 신뢰 손실이다.

**고칠 방법**: (a) `bus_arrival_card.dart:105`에서 `stopName.isEmpty`면 `'· $stopName'` 세그먼트(Expanded 블록)를 생략한다 — 1줄. (b) noStop 분기에서 헤더를 비대화형으로 만든다: `onToggleExpanded`가 null일 때 `_header()`가 `GestureDetector`와 chevron을 생략하도록 하고(`onToggleExpanded`를 nullable로), `bus_card_host.dart:202`는 null을 넘긴다. 두 수정 모두 위젯 테스트 1개로 고정할 수 있다.

---

# 🟡 구획 C. 출하 후 (26건)

## C-1. 사용자에게 보이는 것 (7건)

### M1. 도시 칩을 바꿔도 옛 도시의 검색 결과가 남는다
> 종합: `logic-5` + `user-visible-truth-9` (한쪽은 WEAKENED — '조용한 오등록'은 반증됨)

**위치**: `bus_stop_search_screen.dart:171`(`onSelected: (_) => setState(() => _city = c)`) · `:220-235`(`_resultRows`) · `:91-113`(`_pick`)

수원시 칩으로 `시청`을 검색해 결과를 본 뒤 성남시 칩을 누르면 `_city`만 갈아치우고 `_results`·`_searched`는 그대로다 → 성남시가 강조된 칩 아래 수원시 목록이 깔린다. 그 행을 탭하면 `_pick`이 stop에 실린 `cityCode: 31010`(수원)으로 조회·저장하므로 **데이터는 어긋나지 않는다**. 심각도를 낮춘 이유: 확인 시트가 그 정류장에 실제로 오는 **노선 번호를 열거**하고(`_routeTile`, `:436-462`) 이 설계의 전제가 '자기가 타는 버스 번호는 안다'(`:259-262` 주석)이므로 도시가 다르면 노선 번호가 통째로 낯설어 같은 시트가 잡아낸다. 남는 결함은 '칩과 목록이 어긋난 화면 상태'다.

**고칠 방법**: `onSelected`에서 함께 리셋 — `setState(() { _city = c; _results = const []; _searched = false; })`. 검색어가 남아 있으면 곧바로 `_search()`를 다시 부르는 편이 마찰이 적다. **I13(PillChip 교체)과 같은 줄이므로 함께 처리할 것.** 가드: 결과가 뜬 뒤 다른 도시 칩 탭 → `ListTile`이 사라지고 `정류장 이름을 입력해 주세요`가 보임.

### M2. `N개 더`가 링크처럼 보이지만 탭 대상이 아니다
> 종합: `logic-6`의 텍스트 부분 + `user-visible-truth-6`

**위치**: `bus_body_text.dart:31-40`

필터 없이 5노선 정류장을 `간단히`로 보면 `2개 더`가 `AppColors.gold` + w600 13px로 뜬다. 스펙 §1의 표(145행)는 `가장 빠른 3개 + N개 더 한 줄. **탭하면 전체**`라고 못박았는데 그 Text는 `Wrap` 안의 맨 `Text`라 `GestureDetector`/`InkWell`이 없다. 같은 카드 안의 골드 텍스트는 전부 탭 대상이다 — `다시 시도`(`bus_empty_state.dart:84-95`) · `정류장 등록`(같은 파일) · `퇴근 보기`(`bus_arrival_card.dart:165-183`). 이 앱은 골드를 의미 토큰으로 관리하는데(CLAUDE.md의 골드 4중 의미 경고) 카드 안에서 골드=행동으로 굳은 상태에서 비행동에 같은 색을 쓴 것은 규칙을 스스로 깬다.

**고칠 방법** — 둘 중 하나를 고르고 **I5(축)에도 같은 결정을 적용**한다.
(a) 약속대로 탭을 붙인다: `BusArrivalCard`에 `onShowAll` 콜백 + 화면 수명 `bool _showAll`로 `busUnfilteredLimit`을 건너뛴다.
(b) 약속을 접고 `AppColors.sub`로 낮춰 정보 라벨로 만들고 **스펙 §1의 "탭하면 전체" 문구를 지운다**.
어느 쪽이든 스펙과 코드 중 하나는 고쳐야 한다.

### M3. `시간 축` 모양은 스크린리더에 도착 시각을 전혀 주지 않는다
> `user-visible-truth-7`

**위치**: `bus_body_axis.dart:94-113`(`_dot`) · `:115-134`(`_labels`)

`_labels()`가 `Positioned`에 `Text(a.routeNo)`만 넣어 `720`·`150`·`15`가 맥락 없이 읽히고, 점(`_dot`)은 `Container` + 색뿐이라 시맨틱 노드가 없다. 도착 분이 **화면 위치로만 인코딩**돼 접근성 트리에 "720이 몇 분 뒤인지"가 한 조각도 없다. 같은 데이터를 `간단히`는 `720번` + `2분` 두 Text로 읽어 준다. 이 리포에는 선례가 있다 — 목록의 중요 ★는 글자가 사라지자 `Semantics(label: CalendarStrings.importantBadge)`로 감쌌다(CLAUDE.md).

**고칠 방법**: `_labels()`의 각 `Text`를 `Semantics(label: '${a.routeNo}번 ${a.arrMin == 0 ? BusStrings.arrivingNow : BusStrings.minutes(a.arrMin)}', child: ...)`로 감싼다(문구는 `간단히`와 같은 상수를 재사용해 두 모양이 같은 사실을 말하게 한다). 눈금 행은 `ExcludeSemantics`로 빼면 중복 낭독이 줄어든다.

### M4. TAGO 호출량 점검이 "관문 4. 출시 후 모니터링(선택)" 아래라 선택 사항이 됐고 주기가 빠졌다
> `user-visible-truth-11`

**위치**: `docs/release_checklist.md:103`(섹션 제목) · `:108-110`(항목)

체크리스트를 위에서 훑으면 관문 1~3(필수)까지 끝내고 `## 🧪 관문 4. 출시 후 모니터링(선택)`에 도달한다 — 제목이 (선택)이므로 건너뛴다. 항목 문구에도 시점이 없어(`넘긴 날이 있으면`) 언제 몇 번 보는지가 남지 않았다. 스펙 §5(545-546행)는 점검 시점을 **"버스 기능이 포함된 릴리즈마다 + 이후 월 1회"** 로 못박고 이 절차의 존재 이유를 "기억에 의존하면 점검하지 않는다"로 적었다. 서버가 없어(스펙 335행) 이 수동 점검이 개발계정 10,000/일 한도의 유일한 관측 수단이고, 놓치면 한도 초과로 전 사용자의 카드가 keyError로 죽는다.

**고칠 방법**: 필수 관문(관문 3의 제출 직전 또는 별도 `관문 3-1`)으로 옮기고 문구에 주기를 넣는다 — `버스 기능이 포함된 릴리즈마다, 이후 월 1회`. 관문 4에는 "월 1회 재확인" 참조만 남긴다. **I10의 "beta 레인 산출물 확인" 항목과 같은 곳에 들어가므로 함께 처리할 것.**

### M5. 시간대 설정이 무효(겹침·뒤집힘)면 카드가 영구히 접히고 제목줄 탭이 완전한 no-op가 된다
> `user-visible-truth-8`

**위치**: `bus_display.dart:33-38`(override보다 먼저 조기 반환) · `bus_card_host.dart:134-156`(`_toggleExpanded`) · `bus_settings_tiles.dart:52-73`

prefs의 `bus_settings_v1`에 두 시간대가 겹치는 값이 들어 있으면 `resolveBusDisplay`가 `!rangesValid`에서 **override를 읽기도 전에** `expanded: false`로 조기 반환한다. 카드는 접힌 줄만 보이고 `_tick`은 요청을 내지 않는다. 제목줄을 탭하면 `_toggleExpanded`가 `setOverride(expanded: true)`를 prefs에 쓰지만 다음 build가 그 override를 다시 무시하므로 **몇 번을 눌러도 펼쳐지지 않고** 설정 탭의 두 시간대 타일은 겹친 값을 정상처럼 표시한다.

도달 경로가 좁아 minor다 — `bus_providers.dart:64-71`의 `setRange`가 `if (!next.rangesValid) return false;`로 저장을 원천 차단하므로 정상 UI로는 이 상태에 갈 수 없다(prefs 손상·수동 편집·향후 스키마 변경만). 그러나 증상은 기능 전체 사망이다.

**고칠 방법**: 폴백 상태를 화면에 표현한다 — `!rangesValid`면 설정 타일에 `BusStrings.rangeOverlap`을 상시 경고로 띄우거나, 최소한 `_toggleExpanded`에서 무효면 저장하지 않고 스낵바로 이유를 말한다. 가장 저렴한 대안: `BusSettingsNotifier.build`에서 읽은 값이 `!rangesValid`면 **시간대만 기본값으로 되돌려 저장한다**(폴백을 눈에 보이는 복구로 바꾼다).

### M6. `_search`/`_loadCities`가 `TagoResult.outcome`을 버려 조회 실패가 `검색 결과가 없어요`로 표시된다
> 원장 지연 항목 재확인(이미 3명이 지연 판정) — 다만 I6·M1과 같은 파일이라 함께 손대면 값이 있다

**위치**: `bus_stop_search_screen.dart:63-70`·`:79-87`

`result.items`만 쓰고 `outcome`을 버려 네트워크 장애·키 오류가 "결과 없음"으로 뭉개진다. 저장까지 이어지진 않고(확인 시트가 별도로 막음) 드문 상황에서만 발현한다. `bus_api_client.dart:29`의 `isOk`(C-4의 죽은 getter)가 이 지점에서 유혹이 되므로 함께 볼 것.

### M7. `"켜지 않으면 어떤 통신도 발생하지 않습니다"`가 절 밖에서 읽히면 앱 전체 주장으로 오독된다
> `secrets-privacy-deploy-8`

**위치**: `docs/privacy_policy.md:85-86`

코드상 이 문장은 **버스 범위에서는 참이다** — 검증했다: `enabled == false`면 `bus_card_host.dart:185`가 `SizedBox.shrink`를 돌려주고, `_tick`의 `shouldPoll`이 `settings.enabled`를 먼저 보며(`:84`), 정류장 타일이 감춰져(`bus_settings_tiles.dart:52`) `/bus/stops`에 닿는 UI 경로도 없다. 문제는 문장이 주어 없이 "어떤 통신도"라고 단정한다는 점이다 — 이 앱은 Google 캘린더 연동으로 이미 네트워크를 쓰고 있어(§3·§5) 절 제목을 놓친 독자에게는 문서가 스스로를 반박한다.

**고칠 방법**: "버스 도착 카드는 기본적으로 꺼져 있으며, 켜지 않으면 **버스 도착 정보 조회를 위한 통신은** 발생하지 않습니다"로 범위를 명시한다. **I14·I15와 같은 파일이므로 한 번에 처리할 것.**

## C-2. 테스트가 다른 이유로 통과하는 곳 (6건)

이 부류는 지금 코드가 옳다 — 가드가 결함을 못 잡는다는 것이 문제다. 이 작업에서 발견된 실제 버그가 모두 "요청 수 단정이 다른 이유로 통과하던" 자리였으므로 우선순위를 낮게 두더라도 목록에서 지우지 말 것.

### M8. 조건 1(`표시 ON`)의 요청 0회 가드가 confound돼 있다 — `settings.enabled &&`를 지워도 618개 전부 초록
> `test-guarantees-2` (WEAKENED — 지금 코드에 결함은 없다)

**위치**: `test/features/bus/bus_card_host_test.dart:98-106` · `lib/features/bus/presentation/widgets/bus_card_host.dart:84`

넘기는 픽스처가 `BusSettings.defaults`이고 여기엔 **슬롯도 없다**. 그래서 `shouldPoll`에서 `enabled`를 통째로 지워도 `stop == null`이 대신 false를 만들어 `expect(n, 0)`이 통과한다(host 테스트 전수 확인: 픽스처는 `defaults`·`defaults.copyWith(enabled: true)`·`onWithStop` 셋뿐이고 **`enabled: false` + 슬롯 있음 조합이 한 건도 없다**. `BusCardHost`를 마운트하는 파일도 이것 하나다). 실제 프로덕션의 흔한 OFF 상태는 `enabled: false` + 슬롯 2개 — 그 상태에서 그 절이 사라지면 카드가 화면에 1픽셀도 없는데 TAGO 요청이 30초마다 나간다. (스펙 §8이 요구한 `findsNothing` 계약은 `build`의 별도 가드 `:185`가 독립적으로 지키므로 계약 자체는 무검증이 아니다.)

**고칠 방법**: 기존 테스트를 지우지 말고 격리 테스트 1개 추가 — `settings: BusSettings.defaults.copyWith(departure: _stop, arrival: _stop)`(enabled는 false 유지) + `now: inRange` → `findsNothing` + `expect(n, 0)`. `settings.enabled &&`를 지우면 이 테스트만 실패하는지(RED) 확인해 증거로 남긴다.

### M9. 조건 5(포그라운드)에 단정이 0 — 백그라운드 타이머 취소와 비행 중 재확인을 둘 다 지워도 전부 초록
> `test-guarantees-6`

**위치**: `bus_card_host.dart:70-73`(라이프사이클 else) · `:119-123`(비행 중 재확인) · `test/features/bus/bus_card_host_test.dart`의 라이프사이클 3개

`paused` 직후가 `pump()`(시간 전진 0)이고 `pumpAndSettle`은 프레임이 예약된 동안만 도는데 `Timer.periodic`은 프레임을 예약하지 않아 30초에 도달하지 못한다. 즉 else 분기를 지워도 세 테스트 모두 count가 같고(테스트 종료 시 `dispose`가 취소해 'Timer still pending'도 안 난다), 유일하게 타이머를 발화시키는 폴링 테스트는 백그라운드로 내려가지 않는다. 여섯 조건 중 **유일하게 단정이 0인 조건**이고 스펙 §5의 호출 예산이 여기 걸려 있다.

**고칠 방법**: 테스트 1개 추가 — 펼침으로 띄워 count 1 확인 → `handleAppLifecycleStateChanged(paused)` → `now`를 31초 전진 → `await tester.pump(busPollInterval)` → `expect(count, 1, reason: '백그라운드에서는 폴링이 멈춘다')`. 취소 분기를 지우면 count 2가 되어 실패한다.

### M10. `parseArrivals`의 `..sort`를 지워도 아무 테스트가 깨지지 않는다
> `test-guarantees-3`

**위치**: `lib/features/bus/data/tago_response_parser.dart:56-57` · `test/features/bus/data/tago_response_parser_test.dart:73-85`

5노선 픽스처의 입력 순서(R1 480 · R2 600 · R3 600 · R4 780 · R5 1860)가 `fastest` Map 삽입 순서 그대로이고, 기대값 `['82-1','92','92-1','81','61']`이 **삽입 순서와 완전히 같다** → `..sort`를 삭제해도 동일한 결과가 나온다(축약 로직만 떼어 실제로 돌려 확인). 나머지 파서 테스트는 단건이거나 `.toSet()`이고 client 테스트도 전부 1항목이라 스펙 §3(449행)의 계약(`축약 후 arrtime 오름차순 정렬`)에 반증 가능한 단정이 0이다. Task 7에서 `filtered.sort`를 지워도 14개가 전부 초록이라 발견된 것과 **같은 종류가 파서에 한 번 더 남아 있다**. 실질 영향은 확인 시트 체크박스 순서뿐이다(`bus_stop_search_screen.dart:391`이 받은 순서대로 그린다 — 카드는 `buildBusCardView:90`이 다시 정렬해 가려준다).

**고칠 방법**: 기존 5노선 테스트의 **픽스처 순서만** 바꿔 첫 등장 순서 ≠ 도착 순서로 만든다(R5/61(1860)을 맨 앞, R1/82-1(480)을 맨 뒤). 기대값은 그대로 두면 되고 `..sort`를 지우는 순간 이 테스트만 실패한다.

### M11. `시간 축`의 점·라벨 실제 위치가 무검증
> `test-guarantees-5`

**위치**: `bus_body_axis.dart:94-104`·`:118-130` · `test/features/bus/bus_body_test.dart:84-91`

`BusBodyAxis 렌더` 테스트는 `지금`·`15분`·`720`의 **존재만** 확인한다. `_dot`의 `left: (dotPosition(arrMin) * width) - (size / 2)`를 아무 식으로 바꾸거나 `_labels`의 `- 14` 중심 보정을 지워도 통과한다 — 실험으로 확인했다: 340폭 Stack 안에 `Positioned(left: 680)`으로 놓아도 `takeException() == null`이고 `find.text`가 `findsOneWidget`이다(`getCenter().dx = 701.4`로 화면 밖). Stack은 Flex와 달리 오버플로를 FlutterError로 보고하지 않고 클립만 한다. 스펙 §8은 이 항목을 **위젯** 테스트로 요구했는데(`점 위치가 분에 비례, 0분·15분 초과가 3~97%로 clamp`) 구현은 순수 함수 4개로만 덮었다 — `시간 축`의 존재 이유가 "간격이 공간으로 보인다"인데 그 공간 매핑이 위젯 레벨에서 한 줄도 고정돼 있지 않다.

**고칠 방법**: 기존 렌더 테스트에 좌표 단정을 한 줄 더한다 — 폭 340의 `SizedBox` 안에서 `tester.getCenter(find.text('720')).dx`가 `dotPosition(2) * 340`에 `closeTo`로 맞는지. 15분 초과 항목을 하나 더 넣어 두 라벨의 dx가 같은 clamp 값으로 모이는지도 함께 본다.

### M12. `'보정된 값 기준으로 상한을 자른다'`는 이름의 계약을 그 테스트가 검사하지 못한다
> `test-guarantees-4` (WEAKENED — 원 발견의 '보정은 단조라 순서를 못 바꾼다'는 근거는 틀렸다)

**위치**: `test/features/bus/domain/bus_card_view_test.dart:92-105` · `lib/features/bus/domain/bus_card_view.dart`의 계산 순서 주석

파이프라인 A(보정→정렬→상한, 현재)와 B(정렬→상한→보정)를 20만 회 무작위 대조했다: **오름차순 입력에서는 차이 0/200,000**(따라서 `parseArrivals`가 항상 정렬해 주는 실제 입력과 `:98`의 픽스처에서는 순서 교환이 관측 불가 — 이 테스트는 이름이 주장하는 계약을 잡지 못한다). 그러나 무작위 입력에서는 **101,689/200,000이 달랐다** — 이유는 '단조성'이 아니라 **클램프가 만드는 동값(tie)** 이다. `buildBusCardView`는 정렬되지 않은 입력을 받을 수 있는 순수 함수이므로 "그런 상황이 발생할 수 없다"는 단정은 성립하지 않는다. 남는 실행 가능한 몫은 **문구 정리**다: 주석의 `보정을 나중에 하면 … 방금 지나간 버스가 목록에 남는다`는 두 순서 모두에서 일어난다(0분 항목을 제거하는 코드가 어디에도 없다 — I1과 같은 근원).

**고칠 방법**: 테스트 이름을 실제 검사 내용으로 바꾸거나(`'상한이 3개를 남기고 첫 항목은 보정으로 0분이 된다'`) `경과 보정` 그룹에 통합한다. 계산 순서 주석에서 근거가 틀린 문장을 빼고, 실제로 순서가 중요한 쌍(`정렬 → 상한`, `필터 → 상한`)만 남긴다.

### M13. 정류장 검색 화면의 도시 복원이 편집 중인 슬롯을 무시한다
> `test-guarantees-7` (WEAKENED — 원 발견이 든 두 시나리오는 제안 수정으로도 결과가 같다)

**위치**: `bus_stop_search_screen.dart:58-71`(특히 `:67`)

`final code = saved?.departure?.cityCode ?? saved?.arrival?.cityCode;`가 `widget.slot`을 보지 않는다. 주석은 `마지막으로 쓴 도시를 기본 선택으로`라고 적었지만 코드는 `출발지의 도시`다. 실제로 달라지는 유일한 경우는 **두 슬롯이 모두 등록된 뒤 한쪽을 재편집할 때**다(도착지=화성인데 수원이 복원됨). 그 경우의 피해도 선택 칩이 화면에 보이고(`_chipCities:187-199`가 맨 앞에 고정) 사용자가 바꿀 수 있어 `검색 결과가 없어요` 한 번의 마찰이다(스펙 §3의 경고 — 잘못된 cityCode도 오류가 아니라 빈 응답이 온다 — 와 겹친다).

**고칠 방법**: `BusSettings.stopFor`가 이미 있으므로 한 줄이다 — `final slot = widget.slot ?? CommuteDirection.toWork; final code = saved?.stopFor(slot)?.cityCode ?? saved?.stopFor(slot.flipped)?.cityCode;`. 주석도 `편집 중인 슬롯의 도시를 먼저, 없으면 반대 슬롯`으로 고친다.

## C-3. 컨벤션·구조 (6건)

### M14. 영문 대문자 장식용 `AppTextStyles.eyebrow`를 한글 라벨·지시문에 쓴다
> `convention-4`

**위치**: `bus_stop_search_screen.dart:154`(`도시`) · `:386-387`(`타는 버스만 남겨주세요`)

`eyebrow`는 10px + `letterSpacing: 2.5` + gold이고 doc이 "제목 위에 얹는 **영문** 소제목(REVIEW·TODAY 등)"이라 적었다. lib의 나머지 사용처는 전부 대문자 영문이다(`schedule_screen.dart:45` `'INPUT'`, `today_screen.dart:35` `'TODAY'`, `section_header.dart:30` `toUpperCase()`) — 이 두 곳만 한글이다. `도시`가 `도 시`처럼 벌어지고, 확인 시트에서 사용자가 할 일을 말하는 **유일한 지시문**이 11글자에 자간 2.5가 붙어 본문(14-15px)보다 작고 골드라 장식 라벨로 읽힌다. 확인 시트는 '방향이 조용히 틀리는 것을 막는' 유일한 관문인데 그 안의 행동 지시가 가장 약한 위계로 그려진다.

**고칠 방법**: `AppTextStyles.label`(11px w600 sub) 또는 이 파일이 이미 쓰는 sub 계열 본문 스타일로 바꾼다. eyebrow의 규칙 자체는 바꾸지 않는다(doc이 이미 영문 전용이라 말한다).

### M15. `BusSettings.clearOverride()`가 copyWith 대신 생성자 조립이다 — CLAUDE.md가 blocking 사례로 못박은 패턴
> `convention-5`

**위치**: `lib/features/bus/domain/bus_settings.dart:83-93`

8개 필드 중 6개를 손으로 열거한다. 지금은 유실이 없지만, 필드를 하나 추가하며 `copyWith`·`toJson`·`fromJson`을 고치고 `clearOverride`를 빼먹으면, 사용자가 제목줄을 눌러 시간대 판정과 같은 상태로 되돌릴 때(`bus_card_host.dart:147-148`의 `clearOverride()`) 새 필드가 `@Default`로 되돌아가고 `_save`가 그 값을 prefs에 덮는다 — 접기 탭 한 번으로 설정이 조용히 초기화된다. CLAUDE.md의 '편집 시트는 반드시 copyWith' 항목이 정확히 이 형태로 `kind`·`googleEventId`·`deviceEventId`를 잃었고 "원인은 필드 하나가 아니라 패턴이다"라고 적었다. 완화 요인: `EventEditDialog`와 달리 생성자·`toJson`·`fromJson`·`clearOverride`가 **전부 같은 파일에 인접**해 놓칠 위험이 상대적으로 낮다.

**고칠 방법**: `copyWith`에 해제 플래그를 두고 `clearOverride()`가 그것을 호출하게 한다 — `BusSettings copyWith({..., bool clearOverride = false})` → `overrideAt: clearOverride ? null : (overrideAt ?? this.overrideAt)`. 그러면 필드 추가 시 고칠 곳이 한 곳으로 모인다. 생성자 조립을 남기려면 최소한 필드 수를 고정하는 가드 테스트를 붙일 것(리포가 calendar 쪽에 한 방식).

### M16. 문자열→enum 폴백 파서가 세 곳에서 세 방식으로 구현됐고, 하나는 `core/router`에 있다
> `convention-6`

**위치**: `lib/core/router/app_router.dart:107-113`(`_busSlot`, for 루프, core의 최상위 private) · `lib/features/bus/domain/bus_settings.dart:125-130`(`_style`, enum이 아니라 **설정 클래스**의 private static) · 대비: `EntryKind.fromValue`(enum의 static, domain/)

같은 일(모르는 값·null이면 폴백)이 세 모양으로 존재하고 서로를 참조하지 않는다. `CommuteDirection`에 값을 추가하거나 쿼리 이름을 바꿀 때 고칠 위치가 **feature 밖(core/router)에 하나 숨는다.** 지금 `?slot=`을 만드는 곳은 세 군데(`bus_card_host.dart` 두 곳 + `bus_settings_tiles.dart:120`)인데 읽는 규칙만 core에 있어 짝이 갈라져 있다. feature-first 규약에서 `CommuteDirection`의 직렬화 규칙은 `features/bus/domain/`에 있어야 하고 리포는 이미 `EntryKind.fromValue`로 그 형태를 정해 뒀다.

**고칠 방법**: `CommuteDirection.fromName(String?)`을 enum static으로 추가하고(`EntryKind.fromValue`와 같은 `firstWhere`+`orElse` 형태) 라우터가 그것만 부르게 한다. `BusSettings._style`도 `BusCardStyle.fromName(String?)`으로 옮기면 세 파서가 한 관용으로 모인다.

### M17. `BusStopConfirmSheet`가 `screens/` 파일 안에 산다
> `convention-7`

**위치**: `bus_stop_search_screen.dart:263-463`(약 200줄, 파일의 43%)

public 위젯 + `static Future<BusStop?> show(...)` + `showModalBottomSheet` 형태가 `calendar/presentation/widgets/event_edit_dialog.dart`·`shared/widgets/confirm_dialog.dart`와 같은데, 그 둘은 `widgets/`에 독립 파일로 있고 이것만 화면 파일에 붙어 있다. `features/bus/presentation/widgets/`는 이미 존재하고 위젯 5개가 들어 있다. 시트를 다른 진입점에서 재사용하려는 순간 `screens/`를 import해야 하고, 시트만 고치는 커밋이 화면 diff와 섞인다(실제로 이 Task의 테스트도 시트만 대상으로 삼았다).

**고칠 방법**: `lib/features/bus/presentation/widgets/bus_stop_confirm_sheet.dart`로 옮기고 화면은 import만 한다. `test/features/bus/bus_stop_search_test.dart`의 import 한 줄만 따라 바뀐다.

### M18. `BusSettingsTiles`는 로딩 중 섹션 본문을 비우는데, 형제 섹션들은 defaults로 즉시 그린다
> `convention-8`

**위치**: `bus_settings_tiles.dart:31-32`

설정 탭을 콜드로 열면 `SharedPreferences.getInstance()`를 기다리는 동안 `valueOrNull`이 null이라 `SizedBox.shrink()`가 반환된다. `SettingsSection`은 제목·부제·Divider를 그대로 그리므로 **'버스 도착 / 오늘 탭 맨 위에…'만 있고 스위치가 없는 빈 섹션**이 보인다. 같은 화면의 `StampSettingsTiles`(`?? StampSettings.defaults`)·`NotificationSettingsTiles`·`ThemeModeTile`(`?? ThemeMode.system`)은 첫 프레임부터 컨트롤을 그린다 — 세 섹션은 채워져 있고 한 섹션만 비어 있는 화면이 된다. '아직 로딩 중'과 '이 섹션은 비어 있음'을 화면에서 구별할 수 없다.

**고칠 방법**: `ref.watch(busSettingsProvider).valueOrNull ?? BusSettings.defaults`로 바꾸고 null 조기 반환을 없앤다(`BusSettings.defaults`가 이미 있고 이 파일이 이미 import한다). 기본값이 `enabled: false`라 감춤 로직도 그대로 맞는다.

### M19. 하드코딩 batch 2번의 대상이 한 곳이 아니라 두 곳이다
> `convention-9` — **이미 판정된 batch 항목의 재상정이 아니라, 그 판정의 적용 범위(목록)가 불완전하다는 지적**

**위치**: 원장 batch 2번이 적은 `bus_body_text.dart:53` + 목록에 없는 `bus_stop_search_screen.dart:450`

같은 리터럴 `'${arrival.routeNo}번'`이 확인 시트의 `_routeTile`에도 있다. batch를 목록대로만 처리하면 카드는 `BusStrings.routeLabel`을 쓰고 시트는 인라인 `번`을 계속 써, 조사를 바꾸거나 노선 표기를 손볼 때 한쪽만 따라간다 — batch 6번(`'${BusStrings.minutes(n)} 후'`)이 카드 표기와 어긋난 것과 같은 갈라짐이 하나 더 남는다. **batch 목록이 곧 작업 지시서라 목록에 없는 호출부는 처리되지 않는다.**

**고칠 방법**: 원장의 batch 2번 항목에 `bus_stop_search_screen.dart:450`을 함께 적고, `BusStrings.routeLabel(String routeNo) => '$routeNo번'` 신설 시 두 호출부를 동시에 바꾼다.

## C-4. 죽은 코드·가짜 강제 장치 (7건 — `simplify` 전부)

각 항목의 참조 위치를 이 리뷰에서 grep으로 재확인했다. 전부 "지워도 컴파일·618 테스트가 그대로"인 것들이다. 리포 원칙 "과잉 엔지니어링 금지 — 실측되지 않은 방어 코드는 부채다"에 걸린다.

| # | 항목 | 위치 | 왜 지워야 하는가 | 지시 |
|---|---|---|---|---|
| M20 | `BusSettings.rangeFor` — 호출자 0 | `bus_settings.dart:54` (선언 한 줄만, grep 확인) | 형제 `stopFor`는 `bus_card_host.dart:82,177,178,188`에서 실제 쓰이는 계약이다. 대칭으로 보이는 둘 중 하나만 살아 있으면 다음 사람이 `rangeFor`도 계약이라 믿고 그 위에 코드를 얹는다. 실제 방향→시간대 경로 둘은 이 메서드를 안 쓴다(`bus_display.dart:92-98`은 방향이 아니라 **시각**으로 고르므로 대체 불가, `bus_settings_tiles.dart`는 타일별로 직접 넘긴다). 원장은 "테스트가 없다"고만 적어 커버리지로 분류했는데 실제 문제는 호출자가 없다는 것이다 | 메서드 2줄 삭제 |
| M21 | `BusStrings.lowFloor` — 그리는 코드 0 | `bus_strings.dart:44` | `BusArrival.lowFloor`는 파서가 채우지만(`tago_response_parser.dart:147`) `BusBodyText`·`BusBodyAxis` 어느 쪽도 읽지 않아 저상 표시가 화면에 나가는 경로가 없다. 스펙 730-746행이 "여력 있으면 Phase 3"으로 남긴 항목이다. 쓰이지 않는 UI 문구가 남으면 다음 사람이 "어딘가 저상 배지가 있다"고 찾아 헤매거나 용어 일괄 변경 때 없는 화면을 위해 문구를 손본다. **하드코딩 batch와 반대 방향**이라 그 batch에 섞이지 않는다 | `bus_strings.dart:44` 한 줄 삭제. `BusArrival.lowFloor` 필드는 파싱 테스트(`tago_response_parser_test.dart:98-101`)가 있고 "기존 테스트 삭제 금지"라 **그대로 둔다** |
| M22 | `BusArrival.prevCnt` — 읽는 표현식 0 | `bus_arrival.dart:10,27,38` + `tago_response_parser.dart:146` | 선언·기본값·`copyWith` 전달·파서 대입 네 줄뿐이고 읽는 곳도 테스트 단정도 0이다. 원장은 "prevCnt 매핑 테스트가 없다"로 커버리지 분류했는데, 그 판정을 따라 테스트를 붙이면 **아무도 쓰지 않는 값을 고정하는 테스트**가 늘어난다(부채를 갚는 게 아니라 굳힌다). `copyWith`가 손으로 전달하는 필드 중 하나여서 CLAUDE.md가 데인 누락 패턴 위험을 대가 없이 키운다 | 필드·기본값·`copyWith` 전달·파서 대입을 함께 삭제. 남은 정류장 수를 화면에 넣기로 결정할 때 그리는 쪽과 함께 다시 넣는다 |
| M23 | `TagoResult.isOk` — 참조 0 | `tago_response_parser.dart:29` | 판정부는 전부 `outcome`을 직접 본다(`bus_api_client.dart:108`의 `switch`가 4갈래를 열거). `isOk`가 남아 있으면 다음 사람이 `if (result.isOk)`로 짧게 쓰고 싶어지고, 그 순간 `keyError`·`malformed`·`empty`가 하나의 else로 뭉개진다 — 스펙 §3이 금지하고 `BusEmptyState`가 와일드카드까지 없애며 지키는 그 구분이다. **M6이 이미 outcome을 버리는 지점이라 유혹이 실재한다** | getter 한 줄 삭제. 판정은 `outcome` 열거로만 |
| M24 | `BusCardStyle.usesSignalColors` — 프로덕션 소비자 0, 주석의 근거가 틀렸다 | `bus_card_style.dart:14,16,25` / 유일 참조 `test/features/bus/domain/bus_stop_test.dart:59-60` | 모양 분기는 `bus_arrival_card.dart:159-162`의 `switch (style)`가 enum 값으로 하고 색은 `bus_body_axis.dart:31-34`가 `AppColors.busSignal*`을 직접 부른다. 유일한 참조는 선언부 리터럴을 되읽는 **항진 단정**이다. 필드 주석은 "가드 테스트가 이 사실을 지킨다"고 적었지만 실제 가드(`bus_body_test.dart:93-101`, `bus_body_text.dart` 소스에 `busSignal` 문자열이 없는지 검사)는 **이 필드를 전혀 보지 않는다** — `axis`에서 true를 지워도 화면은 1픽셀도 안 바뀐다. 클래스 주석의 `SealStyle`과 같은 구조라는 비유도 절반만 맞다(`SealStyle.isSquare`·`usesIcon`은 위젯이 실제로 읽어 그린다) | 필드·생성자 파라미터·항진 단정 2줄을 삭제하고 doc 주석을 실제 가드를 가리키게 고친다 — "기본 모양은 신호색을 쓰지 않는다 — `bus_body_test.dart`의 소스 가드가 지킨다" |
| M25 | 도달 불가 콜백 2개를 매 build마다 만든다 | `bus_card_host.dart:235`(`onRetry`) · `:259`(`onRegister`) | (a) `:235`는 `state: ok` + `visible: const []`를 넘기고 `bus_empty_state.dart:35`의 ok 튜플이 `action = null`이라 `:82`의 `if (action != null)` 게이트에서 `GestureDetector`가 아예 안 그려진다. (b) `:259`의 `view.state`는 `fetch.state`이고 `BusApiClient`가 낼 수 있는 값은 `ok·closed·stale·down·keyError` 다섯뿐 — `noStop`을 만드는 곳은 `:193` 한 곳뿐이고 `onRegister` 소비처는 `bus_empty_state.dart:51`의 noStop 분기뿐이다. **부채가 비대칭이다**: 도달 불가 `onRegister`는 3줄 주석으로 정당화되고 같은 성질의 `onRetry`는 설명이 없어, 어느 쪽이 계약이고 어느 쪽이 형태 맞춤인지 구별할 단서가 주석의 유무뿐이다 | `:235`의 `onRetry: _tick`과 `:259`의 `onRegister:` 3줄을 지운다(주석도 함께). 형태 맞춤을 택한다면 반대로 `onRetry`에도 같은 주석을 달아 **대칭**으로 남긴다 — 지금처럼 한쪽만 설명된 상태가 최악이다. ⚠️ **I11(in-flight 가드)이 `onRetry`를 손대므로 순서를 정할 것** |
| M26 | `_envKey` 주석이 Task 15가 보안 이유로 버린 주입 방식을 안내한다 | `bus_api_client.dart:21` | 주석은 "`--dart-define=TAGO_KEY=...`로 넣는다(`SCREENSHOT_MODE`와 같은 패턴)"고 적혀 있는데, 리포에서 이 키를 넣는 유일한 경로는 `Fastfile:329`의 `--dart-define-from-file`이다. 그 형태로 바꾼 이유가 원장에 있다: `fastlane sh`가 `log: true` 기본으로 명령 문자열을 echo하므로 argv에 실으면 **매 beta 로그에 키가 평문으로 남는다**(이 작업 전체의 유일한 Critical). 즉 주석은 방금 막은 누수를 되살리는 절차를 지시한다. 인용한 `SCREENSHOT_MODE`는 실제로 `--dart-define=`이지만 비밀이 아니라 안전한 참조다. 완화: `Fastfile:314-319`에 상세 경고가 인접해 있어 반복 확률은 낮지만 0은 아니다 | 주석을 실제 경로(`--dart-define-from-file` + tmp JSON)로 고치고 **금지 이유를 한 줄로 함께 남긴다**. `SCREENSHOT_MODE` 비유는 "비밀이 아닌 값"이라는 차이 때문에 오해를 부르므로 뺀다 |

---

# 미검증 — 실기기·시뮬레이터 확인이 필요한 항목

이 리뷰는 정적 분석 + 위젯 테스트 재현까지다. 아래는 **네트워크·실제 렌더가 필요해 이 환경에서 확인할 수 없었다.** 사용자 전역 메모리 규칙(`Simulator before deploy`: 배포 전 항상 시뮬레이터로 런타임 동작 확인, 못 밟으면 미검증 명시)이 이 브랜치에도 적용된다. **Task 15(키 주입) 이후 시뮬레이터로 실제 TAGO 왕복을 확인한 기록이 SDD 폴더 어디에도 없다.**

| # | 확인할 것 | 왜 코드로는 안 되는가 |
|---|---|---|
| V1 | **실제 TAGO 왕복** — 키가 주입된 빌드에서 도착 목록이 실제로 뜨는가 | 모든 테스트가 `MockClient`다. 실 응답 필드명·타입(`arrtime` num vs String)은 스펙 실측에만 근거한다 |
| V2 | **폴링이 눈으로 갱신되는가** — 30초마다 분이 줄어드는가 | I2·I3이 이 경로의 결함이므로 수정 후 반드시 눈으로 볼 것 |
| V3 | **B1 재현·수정 확인** — 오늘 탭 → 캘린더 → 오늘 왕복 후 카드가 사는가 | 위젯 테스트로 재현했으나 실제 ShellRoute 전환에서 최종 확정할 것 |
| V4 | **키 없는 빌드의 `emptyKey` 문구** — 무한 로딩이 아니라 문구가 뜨는가 | I10의 수동 빌드 경로가 정확히 이 상태를 만든다 |
| V5 | **라이트 팔레트에서 `시간 축` 세 점 구별** | `AppColors.busSignal*` 3색의 라이트 대비는 hex 부등호 테스트(`bus_tokens_test.dart:25`)로만 덮여 있다 |
| V6 | **다크에서 표시 스위치 ON 썸**(I12)·**선택된 도시 칩 라벨**(I13) | 두 건 모두 색 계산으로 도출했다 — 실제 렌더로 확정할 것 |
| V7 | **도시 칩 138개 렌더** — `_chipCities`가 20개로 줄이는 동작 + 스크롤 | 네트워크 필요(`fetchCities`) |
| V8 | **iOS 실기기 라이프사이클** — 백그라운드 진입 시 폴링 정지(조건 5) | M9이 이 조건의 단정이 0이라고 지적한 곳이다 |

---

# 지연 백로그 분류 결과 (요약)

원장의 하드코딩 batch 7건 · Task 1~14 minor(deferred) · parked 항목 전부를 실제 코드에서 재확인했다 — **전부 여전히 실재하며 하나도 이후 Task에서 우연히 고쳐지지 않았다.** 대부분(약 30건)은 디버그 문자열·테스트 커버리지 공백·순수 스타일로 '출하 가능'이 맞다. 재분류·주의가 필요한 것만 적는다.

1. **⚠️ 사용자 승인이 선행돼야 하는 batch 항목 1건** — batch 3번(`AppSizes.spacing2` 신설, `bus_empty_state.dart:72`·`bus_body_axis.dart:42,44`)은 나머지 6건(BusStrings 로컬 리팩터)과 달리 **`core/constants/` 전역 토큰 변경**이라 CLAUDE.md '위험한 작업 사전확인'에 걸린다. batch를 한 커밋으로 처리하더라도 **이 1건만은 별도 승인이 선행돼야 하며 나머지 6건과 같은 자동 승인 경로로 묶으면 안 된다.**
2. **'출하 가능' → '필수' 재분류 2건** — noStop 카드의 빈 이름 가운뎃점 + 죽은 chevron → 본문 **I16**으로 승격(첫 화면 + 수정 1~2줄).
3. **batch 목록 자체가 불완전** — 본문 **M19**(batch 2번의 두 번째 호출부).
4. **커버리지 분류가 잘못된 3건** — 원장이 "테스트가 없다"로 적은 `rangeFor`·`prevCnt`·`usesSignalColors`는 실제 문제가 **호출자/소비자가 없다**는 것이다(M20·M22·M24). 그 판정을 따라 테스트를 붙이면 죽은 코드를 굳힌다.
5. **도달 불가로 확인돼 안심할 수 있는 2건** (지금 구조에 한정)
   - parked의 "비행 중 응답이 슬롯 교체를 덮는다": `onRegister`는 noStop에서만 호출되고 그 상태에서는 `stop == null`이라 `shouldPoll`이 거짓 → in-flight 요청이 존재할 수 없다. 설정 탭 경로는 오늘 탭이 dispose된 뒤라 무관. **'이미 등록된 정류장을 오늘 탭 카드에서 바로 교체'하는 기능이 추가되면 즉시 위험해진다** — generation 토큰 하나로 닫힌다.
   - `context.pop()`의 `canPop()` 무가드(`bus_stop_search_screen.dart:113`): `/bus/stops` 진입부 3곳이 전부 `context.push`라 현재는 항상 pop 가능. 딥링크 등 새 경로가 생기면 재점검.
6. **load-bearing인데 무주석·무테스트 1건** — `_fallback`의 `cached.arrivals.isEmpty` 절(`bus_api_client.dart:170`). 직접 트레이스해 실제로 load-bearing임을 재확인했다: 이 절을 빼면 '막차 후(closed, 빈 캐시) → 다음 폴링 실패'에서 `down`/`keyError`가 fetchedAt 있는 `stale`로 잘못 승격돼 `지금 정보를 못 받았어요` + `07:32 기준 갱신 실패`가 동시에 뜨는 부정확한 조합이 된다. **I1이 이 함수를 손대므로 그때 주석 한 줄을 함께 넣을 것.**
7. **설계 질문 1건** — `today_screen.dart:41-57`이 카드를 `data:` 분기에만 넘겨 오늘 탭 로딩·에러 프레임에는 버스 카드가 없다. `todayViewProvider`가 로컬 sqflite라 loading이 대개 한 프레임 이하여서 체감은 낮지만, **B1과 근본 원인(오늘 탭 전체가 매번 dispose·재생성됨)을 공유**하므로 B1을 고치면 실질 영향도 함께 줄어든다.

---

# 함께 고치면 비용이 겹치는 묶음

수정 순서를 정할 때 참고할 것.

| 묶음 | 항목 | 이유 |
|---|---|---|
| **A. `_fallback` + 표시 나이 상한** | I1 · I3 · 백로그 6 | 상수 하나(`busMaxDisplayAge`)가 stale 상한과 표시 드롭을 함께 정의한다. 두 곳에 다른 숫자를 박으면 어긋난다 |
| **B. `bus_card_host` 촉발·정리** | B1 · I2 · I11 · M25 | 같은 파일의 `_tick`/리스너/콜백. B1의 `listenManual` 전환이 리스너 콜백을 메서드로 추출하므로 그때 I2의 setState와 M25의 죽은 콜백 정리를 함께 |
| **C. 검색 화면** | I6 · I13 · M1 · M6 · M13 · M14 · M17 | 한 파일(`bus_stop_search_screen.dart`)이고 **테스트가 0인 화면**이다. 손대는 김에 화면 위젯 테스트 1~2개를 신설할 것 |
| **D. 처리방침** | I14 · I15 · M7 (+ 스펙 §7 문구) | 같은 문서. 개정 이력이 한 줄로 끝나도록 한 번에 |
| **E. 배포 문서·레인** | I9 · I10 · M4 | `Fastfile` + `CLAUDE.md` + `release_checklist.md` |
| **F. 빈 카드 첫 화면** | I16 · M25(b) | `bus_arrival_card._header()`와 noStop 분기를 같이 본다 |

---

# 최종 판정

**이대로 병합할 수 없다.** blocking 1건(**B1** — 설정에서 켠 직후와 탭 왕복 후 카드가 영구 로딩, 실행 재현됨)이 기능을 실사용의 대부분에서 무력화한다. 병합 조건은 다음 세 가지다.

1. **B1을 고치고 warm-mount 가드 테스트를 남긴다**(`listenManual(fireImmediately: true)` + 같은 컨테이너를 먼저 resolve한 뒤 마운트해 `count == 1`을 단정).
2. **I1~I4를 함께 고친다** — 넷 다 카드가 **거짓을 자신 있게 말하는** 부류다: 지나간 버스를 `곧 도착`(I1) · 얼어붙은 카드가 살아 있는 척(I2) · 30초마다 목록이 사라짐(I3) · 다른 버스가 오는데 `오늘 운행이 끝났어요`(I4). 이 카드의 유일한 용도가 "지금 나갈지 판단"이므로 이 넷은 기능의 존재 이유를 깨고, 수정 비용은 상수 1개 + 분기 2개 + 새 상태 1개로 작다.
3. **시뮬레이터로 V1~V4를 한 번 밟는다**(실제 TAGO 왕복 · 폴링 갱신 · 탭 왕복 후 카드 생존 · 키 없을 때 문구). 이 리뷰는 위젯 테스트 재현까지이고, 사용자 규칙상 배포 전 런타임 확인이 필수다.

나머지 important 11건(I5~I15) 중 **문서 3건(I14·I15·M7)은 공개 호스팅 문서라 병합과 같은 커밋에 넣는 편이 싸다**(웹에 올라간 뒤 고치면 개정 이력이 늘고 심사 중이면 되돌리기가 비싸다). I16(첫 화면 결함 2개)은 수정 1~2줄이라 함께 넣기를 권한다. I8~I13은 병합 후 첫 후속 커밋으로 미뤄도 데이터 손실이 없다. minor 26건은 출하 후 batch로 묶어도 되며, 그중 `AppSizes.spacing2` 1건만 별도 사용자 승인이 선행돼야 한다.
