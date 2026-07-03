# 캘린더 날짜 점프 + 중요(★) 태그 — 설계

## 개요
① 캘린더 격자에서 날짜를 누르면 아래 목록이 그 날짜 섹션으로 스크롤·강조된다(빈 날은 다음
가까운 날). ② 캘린더 이벤트에 "중요" 플래그를 두고, 격자엔 골드 별(★)·목록엔 ★ 중요 배지+
골드 레일로 강조. 편집 다이얼로그 토글로 설정. **색 규칙(일/공휴일 빨강·토 골드·이벤트 점
네이비)은 안 건드리고 형태(★)로만 구분.** 캘린더 이벤트 한정(일정 검토 미적용).

## Feature A — 날짜 점프
- 현재: 격자 탭 → `selectedDateProvider`만 갱신, 목록(한 달 전체 날짜별 그룹)은 스크롤 안 함.
- 변경: `calendar_screen`의 월 이벤트 리스트에 `ScrollController` + 각 날짜 그룹에 키/오프셋.
  `selectedDate` 변경을 구독해 그 날짜 그룹으로 `Scrollable.ensureVisible`/`scrollTo`.
- 빈 날: 그 날짜 이후 **가장 가까운 다음 그룹**으로. 이후가 없으면 마지막 그룹.
- 도착 지점 1.6초 골드 플래시(AnimatedContainer/한 회성 하이라이트).
- 순수 로직 분리: `nextGroupIndexFor(sortedDateKeys, selectedKey) -> int` 순수 함수(유닛 테스트).

## Feature B — 중요(★) 태그
- **DB v5→v6**: `ALTER TABLE calendar_events ADD COLUMN is_important INTEGER NOT NULL DEFAULT 0`
  (`_onUpgrade`에 `oldVersion < 6` 블록, 기존 deleted_at/completed_at 패턴과 동일).
- **모델**: `CalendarEvent.isImportant` (bool, JsonKey `is_important`). `fromMap`은 `== 1`,
  `toMap`은 `? 1 : 0`. Freezed `@Default(false)`.
- **편집 다이얼로그**: `_isImportant` 상태 + "★ 중요 표시" SwitchListTile. `_buildEvent`에
  `isImportant` 반영. (색상 피커 제거로 빈 자리에 배치)
- **렌더 — 격자**(`calendar_day_cell`): 그 날 이벤트 중 하나라도 important면 점 대신/함께 골드 ★
  (기존 dot 로직에 분기; 완료 이벤트는 제외해도 됨).
- **렌더 — 목록**(`event_list_section`): important 이벤트 카드 → 골드 레일 + `★ 중요` 배지 +
  옅은 골드 배경. (기존 accentColor 통일 로직에 important 우선 분기)

## 테스트
- 유닛: 마이그레이션 v5→v6 컬럼 존재, CalendarEvent round-trip(is_important), `nextGroupIndexFor`.
- 위젯: 편집 토글 저장, 목록 카드 중요 렌더(배지 존재), 격자 셀 important ★.
- E2E(iPhone 시뮬): 이벤트 편집→중요 켜고 저장→목록 배지 확인 / 날짜 탭→스크롤(가능 범위).

## 범위 밖 (YAGNI)
- 일정 검토(schedule) 중요 태그, 중요만 필터, 중요 정렬 우선, 중요 알림 강화.

## 설계 근거
- 형태(★)로 구분해 기존 색 의미체계와 충돌 회피. DB는 기존 ALTER 패턴 재사용(기존 데이터 보존).
- 날짜 점프는 필터가 아니라 스크롤 — 한 달 맥락 유지(v85 대기중심 뷰 철학과 별개, 캘린더는 전체 표시).
