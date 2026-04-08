# PlanRoutine (플랜루틴)

교사용 일정 관리 앱 — 매년 반복되는 업무 일정을 작년 데이터 기반으로 빠르게 세팅.

## 주요 기능

| 기능 | 설명 |
|------|------|
| **CSV 가져오기** | 나이스 생산문서등록대장 CSV 업로드로 작년 업무 일정 자동 파싱 |
| **비교 뷰** | 작년 일정 vs 올해 일정 나란히 비교, 매칭(정확/유사/미매칭) 자동 분류 |
| **검토 후 확정** | 가져온 일정을 바로 등록하지 않고 검토 단계를 거쳐 선택적 확정 |
| **자체 캘린더** | 월간 캘린더 뷰, 이벤트 CRUD, 확정된 일정 자동 반영 |

## 기술 스택

- **Flutter 3.x** (iOS + Android)
- **Riverpod** (상태 관리)
- **GoRouter** (라우팅)
- **sqflite** (로컬 DB)
- **Freezed** (불변 도메인 모델)
- **csv / file_picker / intl**

## 시작하기

```bash
# 의존성 설치
flutter pub get

# 코드 생성 (Freezed 모델)
dart run build_runner build --delete-conflicting-outputs

# 실행
flutter run
```

## 앱 구조

4개 탭 기반 네비게이션:

```
캘린더 | 가져오기 | 일정 | 비교
```

### 데이터 흐름

```
CSV 파일 → [가져오기] → imported_schedules DB
                              ↓
                        [비교] 작년 ↔ 올해 매칭
                              ↓
                     [일정] 검토 → 확정
                              ↓
                     [캘린더] 이벤트 자동 생성
```

## 샘플 데이터

`data/sample/2025_생산문서등록대장.csv` — 65건의 실제 업무 데이터 포함.

## 라이선스

Private
