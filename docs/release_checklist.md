# 공직플랜 출시 체크리스트

현재 상태: TestFlight v47 배포. **외부 공개를 위해서는 아래 항목을 순서대로**
진행해야 합니다. 각 관문은 앞 단계가 끝나야 다음 단계가 열리는 의존 구조.

## 🔐 관문 1. 개인정보 처리방침 웹 호스팅

Google OAuth verification과 App Store 심사 둘 다 **공개된 URL**의 개인정보
처리방침을 요구합니다. 문서 자체는 `docs/privacy_policy.md`에 있으니 이를
웹에 띄우면 됩니다.

추천 호스팅 방법 (무료·빠름·충분):

| 방법 | 특징 | 설정 난이도 |
|---|---|---|
| **GitHub Pages** (`indibery.github.io/planroutine/privacy`) | 저장소 Settings → Pages만 활성화하면 바로 서빙. Markdown 자동 렌더 | ★ |
| **Vercel / Netlify** | 사용자화 레이아웃 필요 시 | ★★ |
| **Notion 공개 페이지** | 복사-붙여넣기만으로 즉시 URL 발급 | ★ |

체크 포인트:
- [ ] `docs/privacy_policy.md` 초안을 리뷰·오탈자 확인
- [ ] 웹 호스팅 선택 (권장: GitHub Pages — 저장소에 이미 커밋됨)
- [ ] 공개 URL 획득 (예: `https://indibery.github.io/planroutine/privacy.html`)
- [ ] 앱 설정 탭 "앱 정보" 아래 또는 "개인정보 처리방침" 외부 링크 타일 추가(선택)

## 🛡 관문 2. Google OAuth 동의 화면 verification

현재 GCP OAuth 동의 화면이 **"테스트 모드"**라 `bery97@gmail.com`만 로그인
가능합니다. 외부 교사들이 Google 캘린더 연동을 쓰려면 "프로덕션" 전환 + 검수
제출이 필요합니다.

GCP Console → API 및 서비스 → OAuth 동의 화면:

- [ ] **앱 정보**: 앱 이름 `공직플랜`, 사용자 지원 이메일, 개발자 연락처
- [ ] **로고**: 120×120 PNG 업로드 (LogoHybrid navy 배경 버전 재사용 가능)
- [ ] **앱 도메인**:
  - 홈페이지: 호스팅된 개인정보 처리방침 도메인 루트 (예: `https://indibery.github.io/planroutine/`)
  - 개인정보 처리방침 링크: 관문 1 URL
  - 서비스 약관: 선택사항 (지금은 생략 가능, 요청되면 동일 도메인에 `terms.html`)
- [ ] **승인된 도메인**: 위 호스팅 도메인
- [ ] **범위(Scopes)**: `.../auth/calendar.events` 하나만 유지
  - **sensitive scope**이므로 **"범위 정당화 비디오"** 또는 스크린샷 요구됨
  - 정당화 예시: "사용자가 공직플랜 앱에서 생성한 일정을 본인의 Google
    캘린더에 저장하는 단방향 동기화 용도. 캘린더 읽기·삭제는 하지 않음."
- [ ] **테스트 사용자** → 프로덕션 전환 후 검수 신청
- [ ] 심사 기간 보통 2~6주. 기간 중에도 테스트 사용자로 제한 운영 가능

## 🍎 관문 3. App Store 심사 제출

모든 자료가 App Store Connect의 "App Information" + "iOS App" 버전 탭에
채워져야 합니다.

### 3.1 앱 메타데이터

- [ ] **앱 이름**: `공직플랜`
- [ ] **부제(Subtitle)**: 30자 이내 한 줄 (예: "교사용 업무 일정 관리")
- [ ] **카테고리**: 주 `생산성` / 보조 `교육`
- [ ] **키워드**: 쉼표 구분 100자 — 교사, 교사앱, 업무일정, 생산문서, 학사일정, 캘린더, 공직, 업무관리
- [ ] **프로모션 텍스트**(170자, 수정 가능): 업데이트 하이라이트용
- [ ] **설명(Description)**: 앱 특징 불릿 + 사용 시나리오. 기존 `CLAUDE.md`의 핵심 기능 7가지를 교사 관점으로 풀어쓰기
- [ ] **저작권**: `© 2026 공직플랜`
- [ ] **지원 URL**: 관문 1과 동일 도메인의 문의 페이지 또는 이메일(mailto:)
- [ ] **마케팅 URL**(선택): 홈페이지

### 3.2 개인정보 처리

- [ ] **개인정보 처리방침 URL**: 관문 1 URL (**필수**)
- [ ] **Privacy "Nutrition Label"** (App Store Connect → App Privacy):
  - 데이터 수집 유형: `Contact Info → Email Address` (Google 로그인 시)
  - 사용 목적: `App Functionality` (Google Calendar 이벤트 생성)
  - 사용자 식별 연결 여부: **아니요** (서버에 전송 안 함)
  - 추적(Tracking): **아니요**

### 3.3 스크린샷

iPhone 6.7" (1290×2796) · 6.1"(1170×2532) 필수. iPad는 선택.

최소 3장 권장:
- [ ] **캘린더 탭** — 골드 로고 + 월 달력 + 이벤트 도트
- [ ] **일정 검토** — 진행도 바 + "전체 확정" pill + 카드 리스트
- [ ] **Import 풀스크린** — 스테퍼 1단계 + 가이드 접힘
- [ ] (선택) 설정 탭 — 섹션 헤더 푸터 + 알림 요약

시뮬레이터에서 captures: Xcode 메뉴 Device → Screenshot (⌘S).

### 3.4 앱 심사 정보

- [ ] **로그인 정보 제공** — Google 계정 기반이라 심사자용 테스트 계정 필요.
      임시 bery97@gmail.com 비밀번호 공유하거나, **Sign-in Info Required**
      체크 해제(Google 미로그인 시에도 기본 기능 동작함 — 오프라인 모드 설명).
- [ ] **검토 노트(Review Notes)**:
  - 앱의 주요 타깃은 한국 초등 교사
  - Google 캘린더 연동은 선택사항이며 미로그인 상태에서도 앱 전체 기능 동작
  - 테스트용 CSV는 `data/sample/2025_생산문서등록대장.csv` 제공 가능
- [ ] **연락처**: 성·이름·전화·이메일

### 3.5 심사 제출

- [ ] TestFlight에서 배포된 최신 빌드(현재 v47) 선택
- [ ] 버전 번호: `1.0.0` (첫 공개 버전)
- [ ] 빌드 중 변경사항이 반영됐는지 확인 (예: Google scope 변경 등)
- [ ] **심사 제출** → 평균 24~48시간 대기

## 🧪 관문 4. 출시 후 모니터링(선택)

- [ ] TestFlight 내부 피드백 채널 정리
- [ ] App Store Connect Analytics 주간 체크 (설치/크래시)
- [ ] 크래시 리포트 연동 — Sentry·Firebase Crashlytics 중 택1 (첫 출시엔 생략 가능, 2차 업데이트에)

---

## 추천 진행 순서

1. **관문 1**(개인정보 처리방침 URL) — 1~2시간
2. **관문 2**(Google OAuth verification 제출) — 자료 준비 1시간, 심사 2~6주
3. **관문 3 병행**(App Store 메타데이터 + 스크린샷) — 2~3시간
4. 관문 2 승인 오기 전에 App Store 심사 먼저 제출해도 무방 (Google 없이 오프라인 모드로도 심사 통과 가능)

## 현재 준비된 자료

- [x] `docs/privacy_policy.md` 초안
- [x] iOS 앱 아이콘 (LogoHybrid 1024px)
- [x] TestFlight v47 안정 버전
- [x] 앱 내 가이드·온보딩
- [x] CLAUDE.md 전체 문서
