# OAuth Verification Demo Video Script

공직플랜 v1.0.1에서 Google 캘린더 기능을 활성화하기 위한 OAuth Verification
신청용 데모 영상 촬영 스크립트. **음성 없이 영어 텍스트 overlay만** 사용.

## 영상 사양

| 항목 | 값 |
|---|---|
| 길이 | ~95초 (최대 2분) |
| 비율 | 세로 9:16 (1080×1920) — iPhone 스크린 레코딩 |
| 음성 | 없음 |
| 자막 | 영어 텍스트 overlay (편집기에서 추가) |
| 업로드 | YouTube **unlisted** |
| 신청서에 첨부 | YouTube 링크 |

## 촬영 전 체크리스트

- [ ] `lib/core/config/app_features.dart`의 `googleCalendarEnabled = true`로 **임시 변경** (촬영 끝나면 다시 false, 신청 직전 빌드부터 true)
- [ ] 촬영 기기는 iPhone 실기기 권장 (Simulator는 OAuth 흐름 경로가 다를 수 있음)
- [ ] iPhone 제어센터 → 화면 기록 버튼으로 녹화 시작
- [ ] OAuth 동의 화면 등장 시 **반드시 좌측 하단 언어 토글을 "English"로 변경하는 동작이 영상에 찍히도록**
- [ ] iPhone 전체 언어를 영어로 바꿀 필요는 없음 (consent screen만 영어면 됨)
- [ ] 마지막 검증 단계에서는 **다른 기기에서 calendar.google.com을 열어** 이벤트가 실제로 생성됐는지 보여주기 (앱 내부 캘린더와 혼동되지 않게)

## 장면별 스크립트

| 시간 | 화면 | English overlay |
|---|---|---|
| **0:00–0:06** | 앱 아이콘 + 캘린더 탭 메인 | `App: PlanRoutine (공직플랜)` <br/> `A schedule manager for Korean elementary school teachers` |
| **0:06–0:14** | 일정 탭에서 카드 두세 개 보여주기 | `Users save in-app events to their personal Google Calendar` <br/> `One-way only: app → Google. Read or delete is never requested.` |
| **0:14–0:22** | 설정 탭 → "구글 계정" 섹션 → "Google 계정 연결" 탭 | `Step 1: User taps "Connect Google Account" in Settings` |
| **0:22–0:38** | OAuth 동의 화면 등장 → **좌측 하단 언어 토글을 English로 변경** → scope 표시되는 순간 약 4초 정지 | `Step 2: OAuth consent screen` <br/> `App name: "PlanRoutine" — same as the app submitted for verification` <br/> ⚠️ scope 라벨은 Google이 자동 표시 |
| **0:38–0:46** | "Allow" 탭 → 앱 복귀 → 설정 탭에 연결된 이메일 표시 | `Step 3: User grants access. Account is now linked.` |
| **0:46–1:08** | 캘린더 탭 → 이벤트 카드 오른쪽 스와이프 → "Google에 저장" 액션 → 토스트 확인 | `Step 4: User swipes an event right to save it to Google Calendar` <br/> `Only this single event is created. The app does not read, modify, or delete any other calendar data.` |
| **1:08–1:25** | 다른 기기 또는 Safari에서 calendar.google.com → 방금 생성된 이벤트 확인 | `Step 5: Verify the event appears in user's Google Calendar` <br/> `Created by PlanRoutine via calendar.events scope` |
| **1:25–1:35** | 앱 메인 화면 + 마무리 | `Scope used: https://www.googleapis.com/auth/calendar.events` <br/> `Purpose: Save user-created in-app events to their personal Google Calendar` <br/> `Read / delete / share: never requested.` |

## Scope Justification (신청서 첨부 텍스트)

```
Scope: https://www.googleapis.com/auth/calendar.events

Justification: Our users (Korean elementary school teachers) create
work-related events in PlanRoutine. After review, they want to mirror
those events to their personal Google Calendar so they receive Google's
own reminders and see them alongside other personal events.

Direction: one-way only. The app writes events to the user's primary
calendar; it never reads existing events, modifies events created by
others, or deletes anything. Each save is initiated by an explicit
right-swipe gesture on a single event card. The app stores the
returned event ID locally only to prevent duplicate writes if the user
swipes the same event twice.
```

## 촬영 후 / 신청 전 체크리스트

- [ ] 영상 편집기에서 위 표의 overlay 텍스트를 시간대에 맞춰 추가 (iMovie / CapCut / DaVinci Resolve 등)
- [ ] YouTube에 **unlisted**로 업로드 (공개 X, 비공개 X)
- [ ] `lib/core/config/app_features.dart`의 `googleCalendarEnabled` 값 확인 — 신청 시점엔 **true**여야 함 (검수자가 "프로덕션" 모드에서 실제 사용 가능한 상태를 확인)
- [ ] OAuth 동의 화면 자료 입력 완료 (`docs/release_checklist.md` 관문 2 참조)
- [ ] 검수 신청 — 평균 2~6주
- [ ] 승인 후: `pubspec.yaml`을 `1.0.1+51`로 bump → TestFlight → App Store 업데이트 제출

## 핵심 검수 통과 요건 (요약)

1. **앱 동일성**: 영상 속 앱 이름·로고가 OAuth 신청서의 client app과 일치
2. **Scope 일치**: consent screen에 표시되는 scope이 신청서 scope과 정확히 동일
3. **언어**: consent screen이 영어로 표시
4. **시연**: 각 scope이 실제로 어떻게 쓰이는지 명확히 보여줌
5. **신청서와 영상의 일관성**: justification에 적은 동작과 영상 시연이 모순되지 않음
