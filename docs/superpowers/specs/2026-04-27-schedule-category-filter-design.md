# 일정 검토 화면 카테고리 필터 설계

작성일: 2026-04-27
대상 화면: `lib/features/schedule/presentation/screens/schedule_screen.dart`

## 배경

일정 검토 화면 타일에는 카테고리 뱃지(`학생학적`, `일과운영` 등)가 보이지만,
정작 검토 작업 흐름에서 "이 분류만 보고 싶다"는 필터가 없다.
사용자(초등 교사)는 매년 수십~수백 건의 일정을 검토·확정해야 하는데,
한 번에 한 분류씩 끊어서 검토하면 인지 부담이 줄고 실수도 줄어든다.

추가로, 현재 일정 수정 바텀시트(`schedule_edit_sheet.dart`)는 카테고리 필드를
표시하지도 편집하지도 않는다. 본 작업에서는 **수정 시트는 의도적으로 그대로 둔다**
— 카테고리는 CSV(생산문서등록대장) 원본 값을 보존하는 게 맞고,
앱 내 임의 편집은 분류 체계를 깨트릴 위험이 있기 때문.

## 결정 요약

| 항목 | 결정 |
|------|------|
| 카테고리 필터 추가 위치 | 일정 검토 화면 상단 필터 바, 상태 필터 아래 줄 |
| 선택 방식 | **단일 선택** (라디오형, "전체" = 필터 해제) |
| 칩 항목 출처 | DB에서 동적 추출 (`SELECT DISTINCT category ...`), 빈도순 정렬 |
| 라벨 표기 | 짧은 alias로 표시(`shortenCategory`), 필터링은 원본 값 사용 |
| 수정 시트 | **변경 없음** — 카테고리 표시·편집 모두 추가하지 않음 |
| "전체 확정" 동작 | **현재 화면에 보이는 카테고리에 한해 확정**으로 변경 |
| Pill 라벨 | `전체 확정` → `이 목록 확정` |
| 다이얼로그 메시지 | "현재 목록의 검토 대기 일정을 확정하시겠습니까?" |

## 데이터 흐름

```
[DB: schedules.category]
        │
   ┌────┴────────────────────┐
   │                         │
getDistinctCategories()   getSchedules(category: ...)
   │                         │
   ▼                         ▼
availableCategoriesProvider  schedulesProvider
   (FutureProvider)            (AsyncNotifierProvider — 기존)
   │                         │
   ▼                         ▼
ScheduleFilterBar          ScheduleScreen 리스트
```

- `scheduleCategoryFilterProvider`(이미 존재, `String?`)에 원본 카테고리 문자열을 그대로 저장.
- 라벨 가공은 표시 직전에만 적용. 필터 쿼리는 항상 원본 값으로 동작.
- 일정 변동(`schedulesProvider` invalidate)이 일어나면 카테고리 풀도 갱신되어야 하므로
  `availableCategoriesProvider`는 `schedulesProvider` 변경에 반응한다.

## 컴포넌트 변경 목록

| 파일 | 변경 |
|------|------|
| `lib/features/schedule/data/schedule_repository.dart` | `getDistinctCategories()` 신규. `confirmAllPending({String? category})` 인자 추가 |
| `lib/features/schedule/presentation/providers/schedule_providers.dart` | `availableCategoriesProvider` 신규. `confirmAllPending`이 카테고리 필터 값을 repository에 전달 |
| `lib/features/schedule/presentation/widgets/category_label.dart` | **신규** — `shortenCategory(String)`, `categoryColor(String)` 모듈 |
| `lib/features/schedule/presentation/widgets/schedule_filter_bar.dart` | 카테고리 줄(가로 스크롤 PillChip) 추가 |
| `lib/features/schedule/presentation/widgets/schedule_tile.dart` | 기존 사설 `_shortenCategory`/`_categoryColor`를 신규 모듈 호출로 교체 |
| `lib/features/schedule/presentation/screens/schedule_screen.dart` | 빈 상태 판정에 카테고리 필터도 포함. 일괄 확정 다이얼로그 메시지 갱신 |
| `lib/core/constants/strings/schedule_strings.dart` | `confirmAll = '이 목록 확정'`로 변경. `bulkConfirmMessage` 갱신 |

## `category_label.dart` 모듈

순수 함수 모음. 표시·테스트 용이성을 위해 위젯에서 분리.

```dart
// 표시용 짧은 라벨. 원본 값은 절대 변형하지 않음
String shortenCategory(String raw);

// pill/뱃지 색상
Color categoryColor(String raw);
```

라벨 매핑 규칙:

| 원본 | 표시 |
|------|------|
| 일과운영관리 | 일과운영 |
| 교육과정계획수립운영 | 교육과정 |
| 조직및통계관리 | 조직통계 |
| 학생학적관리 | 학생학적 |
| 학교행사자율활동 | 학교행사 |
| 포상수상대장관리 | 포상수상 |
| 학교생활세부사항기록부관리 | 학교생활 |
| 학교운영계획수립실적관리 | 학교운영 |
| 인사징계위원회구성운영 | 인사징계 |
| (그 외) | 앞 4글자 + (5글자 이상이면 `…`) |

색상은 기존 `AppColors.categoryDailyOps`/`Curriculum`/`Organization`/`StudentRecord` 4종을
4개 주요 카테고리에 매핑하고, 나머지는 `categoryDefault` 회색.

## 필터 바 레이아웃

기존 1줄 → 2줄로 확장.

```
[✓전체] [검토대기] [확정됨]                                   ← 상태 (기존)
[✓전체] [일과운영] [교육과정] [조직통계] [학생학적] [학교행사] →  ← 카테고리 (신규, 가로 스크롤)
```

- 카테고리 줄은 빈도순 정렬(가장 많이 등장하는 분류가 앞).
- 카테고리가 0개일 때(임포트 전) 또는 모두 NULL일 때 **줄 자체를 숨김**.
- 기존 `PillChip` 위젯 그대로 재사용. 단일 선택이라 UI 패턴은 상태 필터와 동일.

## 동작 시나리오

| 시나리오 | 결과 |
|----------|------|
| 임포트 직후 진입 | 상태=전체, 카테고리=전체 → 전체 일정 표시. 카테고리 칩에 빈도순으로 분류 노출 |
| `학생학적` 칩 탭 | 카테고리=`학생학적관리` 저장 → 해당 카테고리만 표시 |
| `학생학적` ∧ `검토대기` | AND 조건으로 교집합 표시 |
| `학생학적` 상태에서 카테고리 `전체` 탭 | 카테고리 필터 해제 |
| 일정 0건 | 카테고리 줄 숨김 |
| 모든 카테고리가 NULL | 카테고리 줄 숨김 |
| 카테고리 필터 켜진 채 `이 목록 확정` 탭 | 그 카테고리의 검토 대기 일정만 확정 + 캘린더 이벤트 생성 |
| 카테고리 필터 끈 채 `이 목록 확정` 탭 | 모든 검토 대기 일정 확정 (현재 동작과 동일) |

## 빈 상태 메시지

`schedule_screen.dart`의 `_buildEmptyState`에서 `hasFilter` 판정을 두 provider 합산으로 변경.

```dart
final hasFilter = ref.watch(scheduleStatusFilterProvider) != null
                || ref.watch(scheduleCategoryFilterProvider) != null;
```

필터 결과가 비었을 때 `ScheduleStrings.emptyFiltered` 메시지 그대로 사용.

## 엣지 케이스

| 상황 | 처리 |
|------|------|
| `category IS NULL` 또는 `''`인 일정 | `getDistinctCategories`에서 제외. `category=전체` 필터에선 NULL 일정도 표시(현 동작 유지) |
| 사용자가 필터에 잡힌 카테고리의 일정을 모두 삭제 | 칩 자동 사라짐(다음 invalidate에서). 빈 결과 화면 표시 |
| 같은 의미의 카테고리가 표기 차이로 둘 등장(예: `조직및통계관리` vs `조직·통계관리`) | 짧은 라벨이 같아 보여도 원본 값으로 필터하므로 동작은 정확. 표기 정정은 앱 책임이 아님 |
| 카테고리 12개 초과 | 가로 스크롤 그대로 처리. 단일 선택이라 화면 밖 칩이 켜졌는지 헷갈릴 위험 없음 |

## 의도적으로 다루지 않는 항목

- **수정 시트의 카테고리 표시·편집** — CSV 원본 보존 정책 유지
- **하위 카테고리(`sub_category`)** — 현재 어디에서도 표시·필터 후보 아님. 본 작업 스코프 밖
- **사용자 정의 카테고리 그룹화** — 1.x 후속 검토 사항
- **i18n** — 한국어 단일 앱

## 테스트 계획

### Repository 단위 테스트
`test/features/schedule/data/schedule_repository_test.dart`

- `getDistinctCategories` — 활성 일정만, NULL/빈 문자열 제외, 빈도순 정렬, 휴지통 항목 제외
- `getSchedules(category: 'X')` — 정확히 그 카테고리만 반환
- `getSchedules(status: confirmed, category: 'X')` — AND 조건
- `confirmAllPending(category: 'X')` — 그 카테고리의 pending만 confirmed로, 다른 카테고리·다른 상태 영향 없음

### 라벨 가공 단위 테스트
`test/features/schedule/presentation/category_label_test.dart`

- 알려진 9개 카테고리 → 정해진 짧은 라벨
- 매칭 안 되는 임의 문자열 → 4글자 + `…` 처리
- 빈 문자열·null-safe 처리

### 통합 테스트

기존 `integration_test/app_test.dart` 11 시나리오 회귀 통과만 확인. 신규 시나리오 추가 없음.

## 출시 영향

- DB 스키마 변경 없음 (마이그레이션 불필요)
- 기존 사용자 데이터 그대로 호환
- 1.0.x 패치로 배포 가능
