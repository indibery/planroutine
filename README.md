# PlanRoutine (공직플랜)

교사용 업무 일정 관리 앱 — 매년 반복되는 업무 사이클을 작년 데이터 기반으로 올해 일정으로 빠르게 세팅. App Store 출시 중(iOS).

## 주요 기능

| 기능 | 설명 |
|------|------|
| **작년 일정 가져오기** | 나이스 생산문서등록대장 CSV 업로드, 또는 학교 행사표 **사진을 AI로 변환**해 붙여넣기로 일정을 불러온다 |
| **검토 후 확정** | 가져온 일정을 바로 등록하지 않고 검토 탭에서 슬라이드로 확정(→)/삭제(←). `전체 확정`으로 일괄 확정, 확정 시 캘린더 이벤트 자동 생성 |
| **자체 캘린더** | 월간 캘린더 + 이벤트 CRUD. 날짜를 누르면 목록이 그 날짜로 스크롤 |
| **중요(★) 태그** | 이벤트에 중요 표시 → 격자엔 골드 ★, 목록엔 ★ 중요 배지로 강조 |
| **이전 연도 자료 표시** | 제목에 지난 연도가 있는 이벤트에 골드 배지, 탭하면 올해로 고쳐 편집 진입 |
| **휴지통** | 일정·이벤트 soft-delete, 30일 후 자동 영구 삭제 |
| **내보내기** | 확정된 일정을 UTF-8 BOM CSV로 공유 |
| **캘린더 연동** | Google 캘린더 / 기기 캘린더로 단방향 이벤트 저장(중복 방지) |
| **로컬 알림** | 이번 주(월요일)·당일 아침 08:00 알림 |
| **화면 테마** | 시스템/밝게/어둡게 — 다크(네이비+골드) / 라이트(쿨 미스트 화이트) |

## 기술 스택

- **Flutter 3.x** — iOS 배포 중, Android는 코드만 존재(미검증)
- **Riverpod**(상태) · **GoRouter**(3탭 Shell + push) · **sqflite**(로컬 DB v6)
- **Freezed + json_serializable**(불변 모델)
- **csv / charset_converter**(EUC-KR·UTF-8 BOM 자동 감지) · **file_picker** · **share_plus**
- **google_sign_in + googleapis**(Google Calendar) · **flutter_local_notifications + timezone**
- 테스트: flutter_test(유닛/위젯) · integration_test(iPhone E2E) · sqflite_common_ffi

## 시작하기

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Freezed 코드 생성
flutter run
```

## 앱 구조

하단 3탭:

```
캘린더 | 검토 | 설정
```

### 데이터 흐름

```
CSV 파일 / 행사표 사진(AI JSON)
        ↓  [검토 탭 · 가져오기]
   imported_schedules DB (원본 CSV) 또는 schedules 직접
        ↓  [검토] 슬라이드로 확정/삭제
   schedules (status: pending → confirmed)
        ↓  확정 시 자동 생성
   calendar_events → [캘린더] 표시 · (선택) Google/기기 캘린더 저장
```

## 샘플 데이터

`data/sample/2025_생산문서등록대장.csv` — **합성** 생산문서등록대장 20건(가상 학교·가명).
파서·필터 테스트용 포맷 예시일 뿐, 실제 학교 PII는 포함하지 않는다. ⚠️ 실제 학교 데이터는 절대 커밋 금지.

## 라이선스

Private
