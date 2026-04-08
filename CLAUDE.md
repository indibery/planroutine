# PlanRoutine (플랜루틴)

## 프로젝트 개요
**PlanRoutine** — 계획(Plan)과 반복(Routine), 교사용 일정 관리 앱.
매년 반복되는 교사 업무 일정을 작년 데이터 기반으로 올해 일정을 빠르게 세팅.
초등학교 교사의 업무 특성상 매년 비슷한 사이클이 반복되므로, 작년 데이터를 기준으로 올해 일정을 검토·확정하는 흐름.

## 핵심 기능
1. **작년 일정 가져오기** — CSV 업로드로 작년 업무 일정 등록 (생산문서등록대장)
2. **비교 뷰** — 작년 내 일정 vs 올해 학교 공식 일정 나란히 표시, 반복 패턴 자동 감지/하이라이트
3. **검토 후 확정** — 일정을 바로 등록하지 않고 검토 단계 거침, 필요한 것만 선택해서 올해 일정으로 확정
4. **자체 일정 관리** — 앱 자체 서브 일정 관리 기능 내장, Google Calendar 연동은 선택사항

## 타깃 사용자
- 매년 비슷한 업무 사이클을 가진 초등 교사

## 기술 스택

| 레이어 | 기술 | 비고 |
|--------|------|------|
| 앱 | Flutter 3.x (Dart) | iOS + Android |
| 상태 관리 | Riverpod | 다른 라이브러리 사용 금지 |
| 라우팅 | GoRouter | |
| 로컬 DB | sqflite | |
| 모델 | Freezed + json_serializable | 불변 객체 |
| CSV 파싱 | csv 패키지 | EUC-KR/UTF-8 인코딩 처리 주의 |
| 파일 선택 | file_picker | |
| 날짜 | intl | 한국어 로케일 |

## 프로젝트 구조

```
planroutine/
├── CLAUDE.md
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants/       # app_strings, app_colors, app_sizes
│   │   ├── theme/           # app_theme
│   │   ├── router/          # GoRouter 설정
│   │   └── database/        # DatabaseHelper (sqflite)
│   ├── features/
│   │   ├── import/          # CSV 가져오기
│   │   │   ├── data/        # csv_parser, import_repository
│   │   │   ├── domain/      # schedule_item.dart (@freezed)
│   │   │   └── presentation/
│   │   ├── compare/         # 비교 뷰
│   │   │   └── presentation/
│   │   ├── schedule/        # 일정 검토/확정
│   │   │   ├── data/        # schedule_repository
│   │   │   ├── domain/      # schedule.dart
│   │   │   └── presentation/
│   │   └── calendar/        # 자체 캘린더
│   │       ├── data/        # calendar_repository
│   │       ├── domain/      # calendar_event.dart
│   │       └── presentation/
│   └── shared/
│       ├── widgets/         # 공통 위젯
│       └── models/
├── data/
│   └── sample/              # 테스트용 샘플 CSV
├── docs/
│   ├── requirements.md      # 기능 요구사항
│   └── data-schema.md       # CSV 컬럼 정의
└── test/
```

## 샘플 데이터
- `data/sample/2025_생산문서등록대장.csv` — 실제 2025년 생산문서 65건
  - 핵심 컬럼: 등록일자, 제목, 과제명, 과제카드명, 결재유형
  - 업무 분류: 일과운영관리(28), 교육과정계획(10), 조직통계(7), 학생학적(4)

## 코딩 규칙
- Feature-first 구조: `lib/features/{기능}/data|domain|presentation/`
- Riverpod Provider: `presentation/providers/`에 배치
- Freezed 모델: 모든 도메인 모델에 `@freezed` 사용
- Null safety: `!` 강제 언래핑 금지
- 하드코딩 금지: 문자열→app_strings, 색상→app_colors, 크기→app_sizes
- 파일명: snake_case / 클래스명: PascalCase
- 한글 UI, 한글 주석
