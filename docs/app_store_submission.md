# App Store Connect 제출 자료 (v1.0.0)

빌드 v48 기준. Google Calendar 기능 플래그 OFF 상태. App Store Connect의
각 필드에 복사·붙여넣기로 바로 쓸 수 있도록 정리.

## 1. App Information

| 필드 | 값 |
|---|---|
| **App Name** | 공직플랜 |
| **Subtitle** (30자) | 교사를 위한 업무 일정 관리 |
| **Bundle ID** | com.planroutine.app |
| **Primary Category** | 생산성 (Productivity) |
| **Secondary Category** | 교육 (Education) |
| **Content Rights** | 본인 소유 콘텐츠 — Yes |

## 2. Pricing and Availability

| 필드 | 값 |
|---|---|
| **Price** | 무료 (KRW 0) |
| **Availability** | 대한민국만 (또는 전세계) — 초등 교사 대상이라 **대한민국만** 권장 |
| **Release** | 승인 후 즉시 / 수동 릴리즈 선택 |

## 3. Version Information (v1.0.0)

### Description (최대 4000자)

```
공직플랜은 초등 교사의 반복되는 연간 업무 사이클을 손쉽게 관리할 수 있는 일정 관리 앱입니다.

■ 주요 기능

· 작년 일정 가져오기
에듀파인 생산문서등록대장 CSV를 업로드해 작년 업무를 그대로 불러옵니다. 카카오톡·메일·AirDrop 등 어느 경로로 받은 파일이든 공유시트에서 "공직플랜으로 열기"를 선택하면 즉시 불러옵니다.

· 검토 후 확정
불러온 일정을 일정 탭에서 슬라이드로 확정하거나 삭제합니다. "전체 확정" 버튼으로 한 번에 올해 일정으로 등록할 수도 있습니다.

· 자체 캘린더
앱 내에서 직접 이벤트를 만들고 편집할 수 있습니다. 종일 이벤트, 이벤트 색상, 설명 등을 지원합니다.

· 로컬 알림
월초, 1주 전, 1일 전에 자동으로 알림을 보내 중요한 업무를 놓치지 않도록 도와줍니다. 알림 시각은 사용자가 직접 조정할 수 있습니다.

· 휴지통 (30일 보관)
삭제된 일정·이벤트는 30일간 휴지통에 보관되며 언제든 복원할 수 있습니다.

· CSV 내보내기
확정된 일정을 UTF-8 CSV로 내보내 Excel·다른 앱과 공유할 수 있습니다. 다시 가져올 때는 확정 상태 그대로 복원됩니다.

■ 개인정보 보호

· 모든 데이터는 사용자의 iPhone 내부에만 저장됩니다. 외부 서버로 전송하지 않습니다.
· 개발자가 사용자의 업무 일정에 접근하거나 수집하지 않습니다.
· 앱을 삭제하면 모든 데이터가 즉시 삭제됩니다.

■ 문의
bery97@gmail.com
```

### Keywords (100자, 쉼표 구분)

```
교사,교사앱,공직,공무원,업무일정,학사일정,생산문서,업무관리,캘린더,일정관리,교직원,에듀파인
```

### Promotional Text (170자, 업데이트 가능)

```
공직플랜 첫 출시 — 에듀파인 CSV를 가져와 올해 업무 일정을 한 번에 세팅하세요. 카카오톡 공유시트에서 바로 가져오기, 월초·1주 전·1일 전 자동 알림으로 중요한 일정을 놓치지 않습니다.
```

### Support URL

```
https://indibery.github.io/planroutine/
```

### Marketing URL (선택)

```
https://indibery.github.io/planroutine/
```

### Copyright

```
© 2026 공직플랜
```

## 4. App Privacy (Privacy Nutrition Label)

App Store Connect → App Privacy → "Data Types":

**본 앱은 데이터를 수집하지 않습니다** — "Data Not Collected" 전부 선택.

이유:
- 일정·이벤트: 사용자 iPhone 내부 SQLite에만 저장, 외부 전송 없음
- 알림 설정: SharedPreferences에 로컬 저장
- 로그인·계정: 없음 (Google 기능은 이번 버전에서 UI 비활성)
- 분석/추적: 없음

**Tracking**: "No, this app does not track users." 선택

## 5. Privacy Policy URL (필수)

```
https://indibery.github.io/planroutine/privacy_policy
```

## 6. Age Rating

- Age Rating: **4+**
- 모든 항목 "None" 선택 (폭력·욕설·성적 콘텐츠·도박 등 전부 없음)

## 7. App Review Information

### Sign-in Information

| 필드 | 값 |
|---|---|
| **Sign-in required?** | **No** (v1.0.0은 로그인 불필요 — 로컬 앱) |

### Contact Information

| 필드 | 값 |
|---|---|
| First name | (본인 이름) |
| Last name | (본인 성) |
| Phone | (연락처) |
| Email | bery97@gmail.com |

### Notes for Review

```
공직플랜은 대한민국 초등 교사의 업무 일정 관리를 돕는 로컬 앱입니다.

■ 기능 개요
- 에듀파인(대한민국 학교 행정 시스템)에서 받은 CSV 파일을 가져와 올해 일정으로 검토/확정
- 자체 캘린더에 이벤트 생성/편집
- iOS 로컬 알림(월초, 1주 전, 1일 전)
- 확정 일정을 CSV로 내보내기

■ 데이터 처리
- 모든 데이터는 기기 내부 SQLite에만 저장됩니다.
- 외부 서버 전송이 전혀 없으며, 개발자도 데이터에 접근할 수 없습니다.
- 사용자 인증·로그인이 필요 없습니다.

■ Google Calendar 연동
- 현재 v1.0.0에는 Google Calendar 기능이 포함되어 있지 않습니다(향후 업데이트 예정).
- google_sign_in 패키지가 pubspec에 남아있지만 실제 호출은 없습니다(기능 플래그 OFF).

■ 테스트 방법
1. "설정 탭 → 작년 일정 가져오기" → "파일 선택"으로 CSV 업로드
2. 테스트용 샘플 CSV가 필요하시면 아래 링크의 data/sample/2025_생산문서등록대장.csv를
   다운받아 사용할 수 있습니다. 파일에는 개인정보가 없는 더미 데이터만 포함되어 있습니다.
   https://github.com/indibery/planroutine/blob/main/data/sample/2025_생산문서등록대장.csv
3. 또는 카카오톡·AirDrop·이메일로 받은 CSV 파일을 탭하고 공유시트에서 "공직플랜"을
   선택하면 앱이 자동으로 열리며 파일이 로드됩니다.

감사합니다.
```

## 8. Export Compliance

| 질문 | 답변 |
|---|---|
| Does your app use encryption? | **Yes** |
| Does your app qualify for exemptions? | **Yes — only uses standard encryption in iOS (HTTPS)** |

→ 따로 제출할 CCATS / Year-end report 없음.

## 9. Screenshots (필수)

### iPhone 6.7" Display (1290×2796) — 필수

현재 사용 가능한 기기: iPhone 14/15/16 Pro Max. 시뮬레이터 가능.

촬영 순서 (3~4장):
1. **캘린더 탭** — 월 달력 + 이벤트 도트 + 하단 3탭
   - 시나리오: 몇 개 이벤트가 있는 4월 달력 + 오늘 21일 강조
2. **일정 검토 탭** — 진행도 바 + "전체 확정" pill + 카드 리스트
   - 시나리오: "8 / 194 · 4% 완료" 상태
3. **Import 풀스크린 (가이드 펼침)** — 스테퍼 1단계 + 에듀파인 annotation 이미지 + A/B 안내
4. **설정 탭** — 깔끔한 섹션 구조 (구글 계정 섹션 없음)

### iPhone 6.1" Display (1170×2532) — 필수

동일 4장을 6.1" 기기로 다시 캡처 (또는 Apple의 자동 크기 변환 사용).

### 캡처 방법

**시뮬레이터**:
1. Xcode → Open Developer Tool → Simulator
2. iPhone 16 Pro Max 선택
3. TestFlight v48 설치 (또는 로컬 debug 빌드)
4. 각 화면 도달 후 **⌘S** 또는 File → Save Screen

**실기기**:
1. 볼륨 ↑ + 사이드 버튼 동시 누름
2. Mac AirDrop으로 가져옴

**가이드**: 스크린샷 배경 잘리지 않게 Portrait 모드로 세로로. 상단 상태바(9:41 · 배터리 100%) 기본값 유지.

## 10. App Icon

- 이미 빌드에 포함 (1024×1024 RGB) — LogoHybrid 디자인
- TestFlight v48 iPhone 홈 화면에서 정상 표시 확인됨

## 제출 순서

1. App Store Connect → **My Apps → + 새 앱 생성** (이미 되어 있으면 skip)
2. 위 값들로 각 필드 채우기
3. **Build 선택**: TestFlight의 v48 (빌드 1.0.0+48)
4. Screenshots 업로드
5. **Submit for Review**

## 심사 기간

- 평균 24~48시간 (빠르면 몇 시간, 드물게 며칠)
- 거절 시 resolution center에서 구체적 사유 + Apple의 요청사항 확인 가능

## 심사 흔한 거절 사유 + 대응

| 사유 | 대응 |
|---|---|
| Sign-in required지만 방법 없음 | v1.0.0은 Sign-in 필요 없다고 명시 — 문제 없음 |
| 스크린샷과 실제 앱 불일치 | v48로 캡처한 스크린샷만 사용 |
| 한국어 전용 앱인데 영어 설명 없음 | 한국어 설명만 유지하려면 "Language" 에서 "한국어" 기본 설정 |
| 개인정보 수집 불일치 | "Data Not Collected" 유지. 심사 노트의 "외부 전송 없음" 문구가 일관성 보강 |
