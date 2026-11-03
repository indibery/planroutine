# 지도 기록 — 쓰기는 바로, 열어 볼 때 잠금 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 지도 기록 탭은 인증 없이 열리고 새 기록·녹음도 바로 되며, 예전 기록을 열 때 처음 Face ID를 묻고, 잠긴 동안 목록은 제목·이름을 가린다.

**Architecture:** 잠금 상태의 주인은 그대로 `GuidanceUnlock` 하나이고, 이것이 `ChangeNotifier`가 되어 목록·이름 추천이 가림을 다시 그린다. 중첩 셸 builder가 경로로 `requiresUnlock`을 정해 게이트에 넘기고, 게이트는 그 값이 true일 때만 덮개·자동 인증을 한다. 목록의 줄·`삭제한 기록`은 `GuidanceUnlock.authenticate`로 그 자리에서 인증한 뒤 이동한다.

**Tech Stack:** Flutter 3.44.8, flutter_riverpod 2.6.x, go_router 15.1.x, local_auth.

**Spec:** `docs/superpowers/specs/2026-11-03-guidance-lock-on-open-design.md`

## Global Constraints

- 열린 경로는 `/guidance`·`/guidance/new`(쿼리 무관) 둘뿐. **모르는 경로는 잠김.**
- 잠긴 동안 학생 이름이 보이면 안 된다: 제목·관련인 줄·`대략` 사건 글·줄의 시맨틱스 이름·사람 필터 칩·이름 추천.
- 15분 규칙(`guidanceRelockAfter`)·가림 면·`SecureWindow`(탭 전체에서 켬)·`useRootNavigator: false` 규칙은 바꾸지 않는다.
- 끊긴 녹음 되살리기(`app.dart`의 `go(guidanceEdit(id))`)는 **묻는다**(사용자 결정) — `app.dart` 무수정.
- 기존 테스트는 지우지 않는다. 기존 `guidance_lock_gate_test.dart` 24건은 `requiresUnlock` 기본값 `true`로 그대로 통과해야 한다.
- 문자열은 `GuidanceStrings`, 색·크기는 토큰. 새 문자열: `lockedRecordTitle = '잠긴 기록'`, `occurredApproxHidden = '시각 대략'`, `backToList = '목록으로'`.
- 대화상자는 `useRootNavigator: false`(가드 `guidance_root_navigator_guard_test.dart`).

## Review Focus

1. 풀린 채 사람 필터를 골라 둔 뒤 15분이 지나 잠김 → 목록이 그 사람만 남은 채로 보이면 안 된다(필터 무시). → Task 4 테스트.
2. 줄을 빠르게 두 번 누름 → 인증 창 1회, push 1회. → Task 2 테스트(`authenticate` 중복 합치기) + Task 4.
3. 새 기록을 쓰던 중 앱을 떠나 16분 뒤 복귀 → 인증 요청 0회, 쓰던 글 그대로. → Task 3 테스트.
4. 기록 보기에 있다가 탭을 옮겨 16분 뒤 돌아옴 → 덮개 + 인증, 덮개의 `목록으로`로 빠져나올 수 있다. → Task 3·6 테스트.
5. 기기 암호 없음에서 줄 누르기 → 안내 창 → `잠금 없이 열기`로 열림. → Task 4 테스트.

---

### Task 1: 경로 판정 + go_router 실측

**Files:**
- Create: `lib/features/guidance/presentation/lock/guidance_lock_routes.dart`
- Test: `test/features/guidance/lock/guidance_lock_routes_test.dart`

**Interfaces:**
- Produces: `bool guidanceRouteRequiresUnlock(String path)` — `path`는 `Uri.path`(쿼리 없음).

- [ ] **Step 1: 판정 테스트** — `/guidance`·`/guidance/new` → false. `/guidance/record/1`·`/guidance/record/1/edit`·`/guidance/record/1/history`·`/guidance/record/1/transcript/2`·`/guidance/trash`·`/guidance/whatever` → true. 끝 슬래시 `/guidance/` → false.
- [ ] **Step 2: go_router 실측 테스트(같은 파일)** — 앱 라우터와 같은 모양의 `ShellRoute(builder: (c, s, child) => _Probe(path: s.uri.path, child: child))`를 `/guidance`·`/guidance/record/:id` 아래 두고, `/guidance`에서 `context.push('/guidance/record/1')` → `_Probe`가 `/guidance/record/1`을 받는지, `pop` 뒤 다시 `/guidance`를 받는지 기록된 경로 목록으로 단언한다.
- [ ] **Step 3: 실행** — `flutter test test/features/guidance/lock/guidance_lock_routes_test.dart`. Step 1은 FAIL(함수 없음). **Step 2가 FAIL이면 멈추고 보고한다** — 설계의 판정 위치(셸 builder)를 바꿔야 한다(스펙 "경로 판정 위치는 실측으로 정한다").
- [ ] **Step 4: 함수 구현** — 끝 슬래시를 떼고 두 경로와 같으면 false, 그 밖은 true.
- [ ] **Step 5: 통과 확인 후 커밋** — `feat(guidance): 잠금이 필요한 경로 판정`

### Task 2: `GuidanceUnlock`이 알리고, 인증을 한곳에서

**Files:**
- Modify: `lib/features/guidance/presentation/lock/guidance_unlock.dart`
- Test: `test/features/guidance/lock/guidance_unlock_test.dart`(없으면 만든다)

**Interfaces:**
- Produces:
  - `class GuidanceUnlock extends ChangeNotifier` — 기존 API 유지. `_unlocked`가 바뀔 때만 `notifyListeners()`.
  - `Future<AuthOutcome> authenticate(DeviceAuthenticator auth, String reason)` — 이미 풀렸으면 즉시 `success`(인증기 호출 없음). 진행 중이면 **같은 Future**를 돌려준다. 예외는 `failed`. `success`면 `markUnlocked()`.
  - `final guidanceUnlockedProvider = Provider<bool>` — `guidanceUnlockProvider`를 watch하고 리스너로 `ref.invalidateSelf()`, `onDispose`에서 리스너 제거, 값은 `isUnlocked`.

- [ ] **Step 1: 테스트** — (a) `markUnlocked` 시 리스너 1회, 이미 풀린 상태에서 다시 부르면 0회. (b) `markBack`으로 만료되면 리스너 1회. (c) `authenticate` 동시 2회 호출 → 인증기 호출 1회, 둘 다 `success`, `isUnlocked`. (d) 인증기 예외 → `failed`, 다음 호출에서 다시 인증기를 부른다. (e) 풀린 상태에서 `authenticate` → 인증기 0회. (f) `ProviderContainer`에서 `guidanceUnlockedProvider`가 `markUnlocked` 뒤 true로 바뀐다.
- [ ] **Step 2: FAIL 확인** — `flutter test test/features/guidance/lock/guidance_unlock_test.dart`
- [ ] **Step 3: 구현.** `noCredentials`는 상태를 바꾸지 않고 그대로 돌려준다.
- [ ] **Step 4: 게이트의 `_authenticate`가 `_unlock.authenticate(...)`를 쓰도록 바꾼다** — `_authing` 플래그는 지운다(중복 방지는 Future 합치기가 진다). setState로 `_noCredentials`만 갱신.
- [ ] **Step 5: 통과 확인** — 새 테스트 + `test/features/guidance/lock/guidance_lock_gate_test.dart` 24건 그대로 통과.
- [ ] **Step 6: 커밋** — `refactor(guidance): 잠금 상태 알림 + 인증을 GuidanceUnlock 한곳에서`

### Task 3: 게이트가 `requiresUnlock`을 받는다

**Files:**
- Modify: `lib/features/guidance/presentation/lock/guidance_lock_gate.dart`
- Test: `test/features/guidance/lock/guidance_lock_gate_open_route_test.dart`

**Interfaces:**
- Consumes: Task 2의 `GuidanceUnlock.authenticate`.
- Produces: `GuidanceLockGate({required Widget child, bool requiresUnlock = true, VoidCallback? onBack})`, `static const backKey = Key('guidance_lock_back')`.

동작:
- `requiresUnlock == false`: 덮개 없음, `initState` 자동 인증 없음, `IgnorePointer`/`ExcludeSemantics` 없음(잠겨 있어도). `resumed`에서 만료면 `markBack`이 조용히 잠그고 **인증하지 않는다**. 가림 면(`_veiled`)·`attach`/`detach`·`SecureWindow`는 지금과 같다.
- `didUpdateWidget`에서 `false → true`이고 잠겨 있으면 자동 인증.
- 덮개에 `onBack`이 있으면 `잠금 해제` 아래 `TextButton(key: backKey, child: Text(GuidanceStrings.backToList))`.
- 게이트는 `guidanceUnlockedProvider`를 watch해 잠금 변화(목록에서 줄 눌러 푼 것 포함)에 다시 그린다.

- [ ] **Step 1: 테스트** — 기존 게이트 테스트의 하네스(가짜 인증기·시계·`lifecycle`)를 본떠: (a) `requiresUnlock: false`로 띄우면 인증 0회, 덮개 없음, 아래 버튼이 눌린다. (b) 열린 채 떠났다 16분 뒤 복귀 → 인증 0회, 덮개 없음, `GuidanceUnlock.isUnlocked == false`(먼저 풀어 둔 뒤). (c) `false → true`로 다시 pump → 인증 1회, 실패면 덮개. (d) 덮개에 `onBack`을 주면 `backKey`를 눌러 콜백이 불린다; `onBack` 없으면 `backKey` 없음.
- [ ] **Step 2: FAIL 확인**
- [ ] **Step 3: 구현**
- [ ] **Step 4: 새 테스트 + 기존 게이트 테스트 24건 통과 확인**
- [ ] **Step 5: 커밋** — `feat(guidance): 게이트가 열린 화면에서는 묻지 않는다`

### Task 4: 잠긴 목록 — 가림 · 줄 누르면 인증

**Files:**
- Modify: `lib/features/guidance/presentation/widgets/guidance_record_tile.dart`
- Modify: `lib/features/guidance/presentation/screens/guidance_list_screen.dart`
- Modify: `lib/features/guidance/presentation/providers/guidance_providers.dart`(`visibleGuidanceRecordsProvider`)
- Modify: `lib/features/guidance/domain/guidance_logic.dart`
- Modify: `lib/core/constants/strings/guidance_strings.dart`(Global Constraints의 문자열 셋)
- Test: `test/features/guidance/presentation/guidance_list_locked_test.dart`, 단위는 `test/features/guidance/domain/` 기존 `formatOccurred` 테스트 파일 옆에

**Interfaces:**
- Consumes: Task 2 `guidanceUnlockedProvider`, `GuidanceUnlock.authenticate`, `deviceAuthenticatorProvider`.
- Produces:
  - `String formatOccurredLocked(GuidanceContent c, {required DateTime now})` — `approx`면 `occurredAt`이 있으면 날짜(`_day`)만, 없으면 `GuidanceStrings.occurredApproxHidden`; 그 밖은 `formatOccurred`와 같다.
  - `GuidanceRecordTile({..., bool locked = false})` — 잠기면 시각은 `formatOccurredLocked`, 제목 자리는 `GuidanceStrings.lockedRecordTitle`(`AppColors.sub`), 관련인 줄 없음.
  - `String guidanceRecordSemanticsLabel(GuidanceRecord r, {required DateTime now, bool locked = false})` — 잠기면 `[formatOccurredLocked, kind.label, (status), lockedRecordTitle]`.

동작(목록):
- `locked = !ref.watch(guidanceUnlockedProvider)`.
- 잠기면 사람 필터 칩을 그리지 않는다. `visibleGuidanceRecordsProvider`는 잠긴 동안 `person`을 **적용하지 않는다**(골라 둔 값은 지우지 않음 — 풀리면 돌아온다. 스펙의 "구현자 판단" 칸, 내 판단).
- 줄·`삭제한 기록` 누르기: 풀렸으면 바로 push. 잠겼으면 `ref.read(guidanceUnlockProvider).authenticate(ref.read(deviceAuthenticatorProvider), GuidanceStrings.unlockReason)` → `success`면 push, `failed`면 머묾, `noCredentials`면 `ConfirmDialog.show(useRootNavigator: false, title: noCredentialsTitle, message: noCredentialsBody, confirmLabel: openWithoutLock)` → 확인 시 `markUnlocked()` 후 push.

- [ ] **Step 1: 단위 테스트** — `formatOccurredLocked`: approx+날짜 있음 → `'11.3 (화)'` 꼴(같은 해), approx+날짜 없음 → `시각 대략`, exact·date는 `formatOccurred`와 같다. 픽스처의 `occurredText`에 `박서준`을 넣고 결과에 없음을 단언.
- [ ] **Step 2: 위젯 테스트(가짜 인증기, 실제 DB는 `runAsync`)** — 기록 2건(제목 `박서준 수업 방해`, 관련인 `박서준`·`김하늘`, 하나는 approx 글 `점심 박서준 다툼`):
  - 잠김: `find.textContaining('박서준')`·`'김하늘'` 0건, **시맨틱스**에서도 0건(`tester.getSemantics`로 줄 이름 확인 또는 `find.bySemanticsLabel(RegExp('박서준'))` 0건), `잠긴 기록` 2건, `personFilterKey` 없음, 구분 칩은 있음.
  - 줄 누르기 + `success` → 인증 1회, 기록 보기 경로로 push(테스트 라우터의 경로 기록으로 확인). 빠르게 두 번 → 인증 1회·push 1회.
  - `failed` → 목록 유지. `noCredentials` → 안내 창 → `잠금 없이 열기` → push.
  - 풀린 상태에서 사람 필터 `박서준` 고름 → 잠금(`markBack` 만료) → 두 기록 모두 보이고 칩 없음.
  - 풀린 상태: 제목·이름 보임(기존 동작).
- [ ] **Step 3: FAIL 확인**
- [ ] **Step 4: 구현**
- [ ] **Step 5: 기존 목록 테스트 손보기** — `guidance_list_screen_test.dart`·`guidance_list_fab_semantics_test.dart` 등 제목·이름·사람 칩을 기대하는 테스트는 `ProviderScope`에 `guidanceUnlockProvider.overrideWithValue(GuidanceUnlock()..markUnlocked())`를 더한다. **선언은 지우지 않는다**(훅이 감소를 막는다).
- [ ] **Step 6: `flutter test test/features/guidance` 통과**
- [ ] **Step 7: 커밋** — `feat(guidance): 잠긴 목록은 제목·이름을 가리고 열 때 인증`

### Task 5: 잠긴 동안 이름 추천 끄기

**Files:**
- Modify: `lib/features/guidance/presentation/widgets/participant_chips_field.dart`
- Test: `test/features/guidance/presentation/participant_chips_locked_test.dart`

**Interfaces:**
- Consumes: Task 2 `guidanceUnlockedProvider`.

동작: 잠기면 `suggestPeople` 결과 대신 빈 목록 — `guidancePeopleProvider`를 **watch하지도 않는다**(명단을 읽지 않는다). 칩 입력(쉼표·엔터·붙여넣기)은 그대로. 키보드 가림 보정(`ensureVisible`)은 추천이 없으면 지금처럼 동작한다.

- [ ] **Step 1: 테스트** — 명단에 `박서준`이 있고 잠김: `박` 입력 → `ParticipantChipsField.suggestionKey('박서준')` 없음, 쉼표 입력 시 칩 생성은 됨. 풀림: 추천 보임.
- [ ] **Step 2: FAIL 확인** · **Step 3: 구현** · **Step 4: 기존 `guidance_edit_screen_test.dart`·`participant_picker_sheet_test.dart` 등 추천을 기대하는 테스트에 Task 4 Step 5와 같은 override 추가, 통과 확인**
- [ ] **Step 5: 커밋** — `feat(guidance): 잠긴 동안 이름 추천을 끈다`

### Task 6: 라우터 배선 + 문서

**Files:**
- Modify: `lib/core/router/app_router.dart`(지도 기록 `ShellRoute` builder)
- Modify: `CLAUDE.md`(핵심 기능 15번 문장, "지도 기록" 절의 잠금 설명), `docs/privacy_policy.md`(지도 기록 잠금 항목), `docs/app_store_description.md`·`docs/play_store_description.md`(잠금 문장이 있으면)
- Test: `test/features/guidance/lock/guidance_router_lock_test.dart`

**Interfaces:**
- Consumes: Task 1 `guidanceRouteRequiresUnlock`, Task 3 `GuidanceLockGate(requiresUnlock:, onBack:)`.

배선: `builder: (context, state, child) => GuidanceLockGate(requiresUnlock: guidanceRouteRequiresUnlock(state.uri.path), onBack: () => context.go(AppRoutes.guidance), child: child)`.

문서 문장(개인정보처리방침·스토어): "지도 기록 탭은 기기 인증으로 잠깁니다" → "지도 기록은 새 기록을 바로 쓸 수 있고, 이미 남긴 기록을 열어 볼 때 기기 인증(Face ID·지문·기기 암호)을 거칩니다. 잠긴 동안 목록에는 날짜와 구분만 보이고 제목과 이름은 가려집니다." 이하 15분·FLAG_SECURE 문장은 유지.

- [ ] **Step 1: 테스트(실제 `appRouter` 또는 같은 모양 라우터, 가짜 인증기 `failed`)** — (a) `/guidance` 진입 → 인증 0회, 덮개 없음. (b) `/guidance/new?record=1` → 인증 0회. (c) `go('/guidance/record/1/edit')`(되살리기와 같은 경로) → 덮개 + 인증 1회. (d) 그 덮개의 `backKey` → `/guidance`, 덮개 없음.
- [ ] **Step 2: FAIL 확인** · **Step 3: 배선** · **Step 4: 통과 + `flutter analyze` + 전체 `flutter test`**
- [ ] **Step 5: 문서 수정** — 스토어 가드(`test/deploy/store_listing_credit_test.dart`)가 다시 통과하는지 `flutter test test/deploy`.
- [ ] **Step 6: 커밋** — `feat(guidance): 쓰기는 바로, 열어 볼 때 잠금 — 라우터 배선과 문서`

### Task 7: 시뮬레이터 확인 (`verify` 스킬)

- [ ] `launch.sh --keep-data` → `설정 › 기능 관리`에서 지도 기록 켬 → 탭 진입: Face ID 창이 뜨지 않는다.
- [ ] `녹음으로 새 기록` → 녹음 화면 → 멈춤 → 저장: 인증 0회(마이크 권한은 `xcrun simctl privacy … grant microphone`).
- [ ] 목록: 제목 대신 `잠긴 기록`, 이름 없음, 사람 칩 없음(`ax.sh ls`로 라벨까지 확인 — 시맨틱스 이름에 이름 없음).
- [ ] 줄 누르기 → Face ID(`notifyutil -p com.apple.BiometricKit_Sim.pearl.match`) → 기록 보기 → 뒤로 → 목록이 다 보인다.
- [ ] 증거: `~/.planroutine/verify/<RUN_ID>/guidance-lock/`. 끝나면 지도 기록을 다시 끈다.
