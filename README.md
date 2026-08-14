# PlanRoutine (공직플랜)

교사용 업무 일정 관리 앱 — 매년 반복되는 업무 사이클을 작년 데이터 기반으로 올해 일정으로 빠르게 세팅. App Store 출시 중(iOS).

## 주요 기능

| 기능 | 설명 |
|------|------|
| **오늘 탭(첫 화면)** | 오늘 처리할 **업무**만 모아 체크 원 탭으로 완료. 완료 순간 골드 도장이 찍히고 상단 결산 링이 차오른다. 기한이 지난 항목은 롤링 7일까지만 기본 접힘 |
| **입력 탭 — 사진 AI(주 경로)** | 월간 일정표를 찍어 `① 프롬프트 복사 → AI 앱 → ② 붙여넣기` 왕복으로 **행사** 등록. 앱은 네트워크를 쓰지 않고 클립보드만 오간다 |
| **작년 업무 가져오기(보조)** | 에듀파인 생산문서등록대장 CSV를 올려 작년 **업무**를 올해 일정으로. 진입점은 입력 탭 히어로의 CSV 카드 한 곳 |
| **업무 / 행사 구분** | CSV 경로 = 업무(내가 처리할 일), 사진 AI 경로 = 행사(학교에서 열리는 일). 오늘 탭에는 업무만, 캘린더에는 둘 다 |
| **검토 후 확정** | 바로 등록하지 않고 입력 탭 검토 목록에서 슬라이드로 확정(→)/삭제(←). 하단 `일괄 업무 확정 N건`/`일괄 행사 확정 N건`으로 종류별 일괄 확정, 확정 시 캘린더 이벤트 자동 생성(종류 승계) |
| **자체 캘린더** | 월간 캘린더 + 이벤트 CRUD. 날짜를 누르면 목록이 그 날짜로 스크롤. 양방향 스와이프(→ Google 저장 / ← 완료 토글) |
| **중요(★) 태그** | 이벤트에 중요 표시 → 격자엔 골드 ★, 목록엔 제목 앞 인라인 ★ |
| **작년 배지 · 연도 밀기** | 에듀파인 CSV로 들어왔고 아직 검토(편집 시트 저장)하지 않은 이벤트에 테두리형 `작년` 배지. 제목의 연도를 한 해씩 미는 칩은 편집 다이얼로그 안에 |
| **휴지통** | 일정·이벤트 soft-delete, 30일 후 자동 영구 삭제 |
| **내보내기** | 확정된 일정을 UTF-8 BOM CSV로 공유 |
| **캘린더 연동** | Google 캘린더 / 기기 캘린더로 단방향 이벤트 저장(중복 방지) |
| **로컬 알림** | 이번 주(월요일)·당일 아침 08:00 알림 |
| **화면 테마** | 시스템/밝게/어둡게 — 다크(네이비+골드) / 라이트(쿨 미스트 화이트) |

## 기술 스택

- **Flutter 3.44.8** (Dart 3.12.2) — iOS 배포 중(App Store, TestFlight `v144`), Android는 Play 비공개 테스트(`versionCode 143`)
- **Riverpod**(상태) · **GoRouter**(4탭 Shell + push) · **sqflite**(로컬 DB v8)
- **Freezed + json_serializable**(불변 모델)
- **csv / charset_converter**(EUC-KR·UTF-8 BOM 자동 감지) · **file_picker** · **share_plus**
- **google_sign_in + googleapis**(Google Calendar) · **flutter_local_notifications + timezone**
- 테스트: flutter_test(유닛/위젯 1003) · integration_test(iPhone E2E 19) · sqflite_common_ffi

## 시작하기

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Freezed 코드 생성
flutter run
```

## 앱 구조

하단 4탭 (초기 라우트 `/today`):

```
오늘 | 캘린더 | 입력 | 설정
```

`/trash`·`/import`는 Shell 안에서 push로 열린다(탭바 유지).

### 데이터 흐름

```
월간 일정표 사진 → AI JSON            에듀파인 CSV
        ↓  [입력 탭 히어로]                  ↓  [/import]
   schedules 직접 (kind=event)     imported_schedules → schedules (kind=task)
                       ↘                  ↙
                schedules (status: pending)
                        ↓  [입력 탭 검토] 슬라이드 · 종류별 일괄 확정
                schedules (status: confirmed)
                        ↓  확정 시 자동 생성 (kind 승계)
                calendar_events
                   ↓                        ↓
        [캘린더] 업무·행사 모두     [오늘] 업무만 · 완료 도장
                   ↓
        (선택) Google / 기기 캘린더 저장
```

**승계 지점이 급소다** — `CalendarRepository.createFromSchedule`이 `schedules.kind`를
이벤트로 옮긴다. 여기서 끊기면 데이터는 멀쩡한데 오늘 탭에 운동회가 뜨는,
원인이 두 레이어 떨어진 버그가 된다.

## 샘플 데이터

`data/sample/2025_생산문서등록대장.csv` — **합성** 생산문서등록대장 20건(가상 학교·가명).
파서·필터 테스트용 포맷 예시일 뿐, 실제 학교 PII는 포함하지 않는다. ⚠️ 실제 학교 데이터는 절대 커밋 금지.

## 더 보기

설계 결정·용어 규칙은 [CLAUDE.md](./CLAUDE.md)가 단일 소스다.
**배포 런북**(명령·레인·게이트·트러블슈팅)은 [.claude/skills/deploy/SKILL.md](./.claude/skills/deploy/SKILL.md) —
CLAUDE.md에는 배포 밖에서도 밟는 급소만 남겨 뒀다.
파일별 상세 구조는 [docs/notes/project-structure.md](./docs/notes/project-structure.md),
데이터 스키마는 [docs/data-schema.md](./docs/data-schema.md).

## 라이선스

Private
