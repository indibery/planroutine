# OAuth Verification Demo Video Script

공직플랜 v1.0.1에서 Google 캘린더 기능을 활성화하기 위한 OAuth Verification
신청용 데모 영상 촬영 스크립트. **음성 없이 영어 텍스트 overlay만** 사용.

## 영상 사양

| 항목 | 값 |
|---|---|
| 길이 | ~110초 (최대 2분) |
| 비율 | 세로 9:16 (1080×1920) — iPhone 스크린 레코딩 |
| 음성 | 없음 |
| 자막 | 영어 텍스트 overlay (편집기에서 추가) |
| 업로드 | YouTube **unlisted** |
| 신청서에 첨부 | YouTube 링크 |

## OAuth Client ID

```
73700230470-cal0r941so2cvip13ro3qt0c750sqkvu.apps.googleusercontent.com
```

`calendar.events`는 **sensitive scope**이라 [Google 공식 요건](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)에 따라 영상 내 OAuth 동의 화면의 **주소창에 client_id가 표시되어야 함**. iOS `google_sign_in` 플러그인은 ASWebAuthenticationSession(주소창 있는 브라우저 view)을 사용하므로 자연스럽게 보임 — 녹화 시 화면 상단을 자르지 않게만 주의.

## 촬영 전 체크리스트

### 1. 앱 빌드
- [ ] `lib/core/config/app_features.dart`의 `googleCalendarEnabled = true`로 **임시 변경** (촬영 끝나면 다시 false, 신청 직전 빌드부터 true)
- [ ] 촬영 기기는 iPhone 실기기 권장 (Simulator는 OAuth 흐름 경로가 다를 수 있음)
- [ ] **테스트 기기에 Google 앱이 설치돼 있지 않음을 확인** — 설치돼 있으면 native flow로 빠져서 URL 주소창이 안 보일 수 있음(client_id 가시성 깨짐). 설치돼 있으면 일시 삭제 후 촬영, 또는 영상 편집 시 Client ID를 prominent overlay로 보강
- [ ] 이전에 Google 로그인한 적 있으면 앱 데이터 초기화하거나 sign-out 상태로 시작 (account chooser 화면이 영상에 나오게)

### 2. GCP OAuth 동의 화면 설정 (영상이 통과해도 이게 안 맞으면 reject)
- [ ] **앱 이름** = `공직플랜` (App Store 등록명과 정확히 동일)
- [ ] **앱 로고** 업로드 (App Store 아이콘과 동일 디자인 권장 — `assets/icon/app_icon.png` 활용)
- [ ] **사용자 지원 이메일** 입력
- [ ] **앱 도메인 → 홈페이지 URL**: `https://indibery.github.io/planroutine/`
- [ ] **개인정보 처리방침 URL**: `https://indibery.github.io/planroutine/privacy_policy.html`
- [ ] **서비스 약관 URL**: `https://indibery.github.io/planroutine/terms.html`
- [ ] **승인된 도메인**: `indibery.github.io`
- [ ] 모든 URL이 실제로 200 응답하는지 브라우저로 확인

### 3. 녹화 환경
- [ ] iPhone 제어센터 → 화면 기록 버튼으로 녹화 시작
- [ ] OAuth 동의 화면 등장 시 **반드시 좌측 하단 언어 토글을 "English"로 변경하는 동작이 영상에 찍히도록**
- [ ] iPhone 전체 언어를 영어로 바꿀 필요는 없음 (consent screen만 영어면 됨)
- [ ] **OAuth 동의 화면 주소창(URL bar)이 화면에 잘리지 않게 녹화** — `client_id=73700230470-...` 파라미터가 reviewer에게 읽힐 수 있어야 함
- [ ] 마지막 검증 단계에서는 **다른 기기에서 calendar.google.com을 열어** 이벤트가 실제로 생성됐는지 보여주기 (앱 내부 캘린더와 혼동되지 않게)

## 장면별 스크립트

| 시간 | 화면 | English overlay |
|---|---|---|
| **0:00–0:06** | 앱 아이콘 + 캘린더 탭 메인 | `App: 공직플랜 (PlanRoutine)` <br/> `A schedule manager for Korean elementary school teachers` <br/> `Same app published on the App Store as 공직플랜` |
| **0:06–0:14** | 일정 탭에서 카드 두세 개 보여주기 | `Users save in-app events to their personal Google Calendar` <br/> `One-way only: app → Google. Read or delete is never requested.` |
| **0:14–0:20** | 설정 탭 → "구글 계정" 섹션 → "Google 계정 연결" 탭 | `Step 1: User taps "Connect Google Account" in Settings` |
| **0:20–0:28** | **Google 계정 선택 화면(account chooser)** 등장 → 테스트 계정 선택 | `Step 2: Google account chooser` <br/> `User selects the account to grant access from` |
| **0:28–0:50** | OAuth 동의 화면 등장 → **좌측 하단 언어 토글을 English로 변경** → URL 주소창의 `client_id` 파라미터가 보이도록 **4~5초 정지** → 화면에 표시되는 모든 요소(로고/scope/링크) 차례로 강조 | `Step 3: OAuth consent screen` <br/> `App name: "공직플랜"` <br/> `App logo: same as the App Store icon` <br/> `OAuth Client ID (visible in URL bar): 73700230470-...apps.googleusercontent.com` <br/> `Privacy policy & Terms of service links visible at bottom` <br/> `Scope shown: See, edit, share, and permanently delete events on Google Calendar` <br/> `All elements match the OAuth client submitted for verification` |
| **0:50–0:58** | "Allow" 탭 → 앱 복귀 → 설정 탭에 연결된 이메일 표시 | `Step 4: User grants access. Account is now linked.` |
| **0:58–1:20** | 캘린더 탭 → 이벤트 카드 오른쪽 스와이프 → "Google에 저장" 액션 → 토스트 확인 | `Step 5: User swipes an event right to save it to Google Calendar` <br/> `Only this single event is created. The app does not read, modify, or delete any other calendar data.` |
| **1:20–1:36** | 다른 기기 또는 Safari에서 calendar.google.com → 방금 생성된 이벤트 확인 | `Step 6: Verify the event appears in user's Google Calendar` <br/> `Created by 공직플랜 via calendar.events scope` |
| **1:36–1:50** | 앱 메인 화면 + 마무리 | `Scope used: https://www.googleapis.com/auth/calendar.events` <br/> `Purpose: Save user-created in-app events to their personal Google Calendar` <br/> `Read / delete / share: never requested.` <br/> `This is the narrowest scope available for write-only event creation.` |

## Scope Justification (신청서 첨부 텍스트)

```
Scope: https://www.googleapis.com/auth/calendar.events

Justification: Our users (Korean elementary school teachers) create
work-related events in 공직플랜 (PlanRoutine). After review, they want
to mirror those events to their personal Google Calendar so they
receive Google's own reminders and see them alongside other personal
events.

Direction: one-way only. The app writes events to the user's primary
calendar; it never reads existing events, modifies events created by
others, or deletes anything. Each save is initiated by an explicit
right-swipe gesture on a single event card. The app stores the
returned event ID locally only to prevent duplicate writes if the user
swipes the same event twice.

Why a narrower scope is not sufficient: calendar.events is already the
narrowest write-capable scope offered by the Google Calendar API.
calendar.events.readonly cannot create events; calendar.app.created is
unsuitable because users want their saved events to live in their
primary personal calendar (visible in their default Google Calendar
views), not in an app-owned secondary calendar. There is no
"events.create-only" or "events.write" variant available.
```

## YouTube 메타데이터 (Unlisted 업로드 시 그대로 사용)

reviewer가 영상 시청 전 description부터 읽고 컨텍스트를 잡습니다. 영어 통일.

### Title

```
OAuth Verification Demo — 공직플랜 (PlanRoutine) — calendar.events scope
```

### Description

```
This video is submitted as part of the Google OAuth verification process for the iOS app "공직플랜" (PlanRoutine), demonstrating use of the sensitive scope `https://www.googleapis.com/auth/calendar.events`.

App information
- App name: 공직플랜 (PlanRoutine)
- Platform: iOS (App Store: https://apps.apple.com/kr/app/공직플랜/id6761813798)
- Homepage: https://indibery.github.io/planroutine/
- Privacy policy: https://indibery.github.io/planroutine/privacy_policy.html
- Terms of service: https://indibery.github.io/planroutine/terms.html
- Audience: Korean elementary school teachers managing yearly work schedules

OAuth client
- Client ID: 73700230470-cal0r941so2cvip13ro3qt0c750sqkvu.apps.googleusercontent.com
- Requested scope: https://www.googleapis.com/auth/calendar.events
- Direction: one-way only (app → Google). The app writes user-created events to the user's primary Google Calendar. It never reads, modifies, or deletes events.

Video contents
1. App identity and branding (App Store name and icon match this app)
2. User taps "Connect Google Account" in Settings
3. Google account chooser
4. OAuth consent screen with English language toggle, displaying the app name, logo, requested scope, and the client_id in the request URL
5. User grants access
6. User saves a single in-app event to Google Calendar via right-swipe gesture
7. Verification that the event appears in the user's Google Calendar

Note: Because iOS uses ASWebAuthenticationSession, the URL bar visually displays the domain (accounts.google.com) only; the full request URL including client_id is shown as a text overlay in the consent screen segment for clarity.

Submission reference: [OAuth verification request ID — to be filled in at submission]
```

### 업로드 설정
- **Visibility**: Unlisted (공개 X, 비공개 X)
- **Audience**: "No, it's not made for kids" (만 13세 미만 대상 아님)
- **Comments**: Off (검수자만 보는 영상이라 댓글 불필요)
- **Category**: People & Blogs 또는 Science & Technology (어느 쪽이든 verification에 영향 없음)

## 촬영 후 / 신청 전 체크리스트

- [ ] 영상 편집기에서 위 표의 overlay 텍스트를 시간대에 맞춰 추가 (iMovie / CapCut / DaVinci Resolve 등)
- [ ] YouTube에 **unlisted**로 업로드 (공개 X, 비공개 X)
- [ ] `lib/core/config/app_features.dart`의 `googleCalendarEnabled` 값 확인 — 신청 시점엔 **true**여야 함 (검수자가 "프로덕션" 모드에서 실제 사용 가능한 상태를 확인)
- [ ] OAuth 동의 화면 자료 입력 완료 (`docs/release_checklist.md` 관문 2 참조)
- [ ] 검수 신청 — 평균 2~6주
- [ ] 승인 후: `pubspec.yaml`을 `1.0.1+51`로 bump → TestFlight → App Store 업데이트 제출

## 핵심 검수 통과 요건 (요약)

1. **앱 동일성**: 영상 속 앱 이름·로고가 OAuth 신청서·App Store 등록 앱과 일치 (`공직플랜`)
2. **End-to-end OAuth 흐름**: 연결 버튼 → **계정 선택 화면** → consent screen → 권한 부여 → 앱 복귀가 모두 영상에 포함
3. **Client ID 가시성** (sensitive scope 필수): consent screen 주소창에 신청서의 client_id가 표시
4. **Consent screen 모든 요소 가시성** (Brand Verification): 앱 이름, 앱 로고, 지원 이메일, 홈페이지 링크, 개인정보 처리방침 링크, 약관 링크
5. **Scope 일치**: consent screen에 표시되는 scope이 신청서 scope과 정확히 동일
6. **언어**: consent screen이 영어로 표시
7. **Scope 사용 시연**: 각 scope이 실제로 어떻게 쓰이는지 명확히 보여줌
8. **신청서·영상·실제 동작의 일관성**: justification → 영상 시연 → 실제 앱 행동이 모두 일치 (예: "단방향 저장만"이라 적었으면 영상에서 캘린더 읽기처럼 보이는 동작 금지)
9. **Scope 협소성 정당화**: 더 좁은 scope으로 안 되는 이유가 신청서에 명시
