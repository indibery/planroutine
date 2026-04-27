# 캘린더 연동 대상 선택 (Google ↔ 기기 캘린더) 설계

작성일: 2026-04-27
대상 화면: 설정 탭 + 캘린더 탭(스와이프)

## 배경

지금까지 캘린더 이벤트의 외부 저장 대상은 Google 캘린더 단일이었다.
Google OAuth verification이 길어 일부 사용자는 OAuth 동의 없이도 시스템 캘린더에
이벤트를 보내고 싶어한다. iOS Calendar / Android Google Calendar 같은 OS의
시스템 캘린더에 저장하는 옵션을 추가해, 사용자가 둘 중 하나를 선택할 수 있게 한다.

향후 Android 출시도 대비해 OS 추상화된 패키지(`device_calendar`)와 일반 명명
("기기 캘린더")으로 설계한다.

## 결정 요약

| 항목 | 결정 |
|------|------|
| 통합 패키지 | `device_calendar` (iOS EventKit · Android CalendarContract 추상화) |
| 동작 방식 | 사용자가 한 번 권한 허용 후 백그라운드 저장 (Google과 동일 UX) |
| 동시 사용 | **단일 선택** (Google · 기기 · 사용 안 함) |
| 설정 UI | 기존 "구글 계정" 섹션을 "캘린더 연동" 섹션으로 통합, 라디오 + 활성 상세 |
| 슬라이드 라벨 | **동적 라벨** — target에 따라 "Google 저장" / "기기 저장" |
| 슬라이드 힌트 | target=none이면 힌트 바 자체 숨김. 외부 저장 슬라이드 비활성 |
| 권한 거부 처리 | SnackBar `[설정 열기]` + 설정 탭에서도 권한 상태 상시 표시 |
| 폴더 명명 | `lib/features/device_calendar/` (iOS·Android 일반화) |
| 기본 캘린더 선택 | 첫 번째 시스템 캘린더에 자동 저장 (선택 UI는 1차 출시 제외) |
| 양방향 동기화 | 안 함 — 단방향(앱 → 외부)만 |

## 아키텍처

```
SharedPreferences ('calendar_target')
        │
        ▼
calendarTargetProvider (StateNotifier<CalendarTarget>)
        │
        ├──→ CalendarIntegrationSection (설정)
        │       ├── Google 선택 시: googleAccountProvider 노출
        │       └── 기기 선택 시:   devicePermissionProvider 노출
        │
        └──→ calendar_screen._onSaveToCalendar (스와이프)
                ├ target == google → GoogleCalendarService.createEvent
                ├ target == device → DeviceCalendarService.saveEvent
                └ target == none   → SnackBar(연동 설정 필요)
```

`features/google/`, `features/device_calendar/`은 평행 — 각자 service + provider만 책임.
target 선택 로직은 `features/settings/`에 두어 두 서비스에 의존성 안 가짐.

## 컴포넌트 변경 목록

| 종류 | 경로 | 책임 |
|------|------|------|
| Create | `lib/features/device_calendar/data/device_calendar_service.dart` | `device_calendar` 패키지 래퍼 — 권한 조회/요청, 이벤트 create·update |
| Create | `lib/features/device_calendar/presentation/providers/device_calendar_providers.dart` | service provider, 권한 상태 provider |
| Create | `lib/features/settings/presentation/providers/calendar_target_provider.dart` | enum + SharedPreferences 영속 |
| Create | `lib/features/settings/presentation/widgets/calendar_integration_section.dart` | "캘린더 연동" 섹션 위젯 |
| Create | `lib/core/constants/strings/calendar_integration_strings.dart` | 라디오/권한/SnackBar 라벨 |
| Modify | `lib/features/calendar/domain/calendar_event.dart` | `deviceEventId` 필드 추가 (Google과 평행) |
| Modify | `lib/core/database/database_helper.dart` | **v5 migration**: `device_event_id` 컬럼 추가 |
| Modify | `lib/features/calendar/data/calendar_repository.dart` | `updateDeviceEventId` 메서드 추가 |
| Modify | `lib/features/calendar/presentation/screens/calendar_screen.dart` | `_onSaveToCalendar`로 일반화, target 분기 |
| Modify | `lib/features/calendar/presentation/widgets/event_list_section.dart` | 슬라이드 background 라벨 동적화 |
| Modify | `lib/features/calendar/presentation/widgets/calendar_slide_hint_bar.dart` | target=none 시 숨김, target에 따라 라벨 |
| Modify | `lib/features/settings/presentation/screens/settings_screen.dart` | `GoogleAccountListTile` → `CalendarIntegrationSection` |
| Modify | `ios/Runner/Info.plist` | `NSCalendarsUsageDescription` 추가 |
| Modify | `android/app/src/main/AndroidManifest.xml` | `READ_CALENDAR` + `WRITE_CALENDAR` 권한 추가 |
| Modify | `pubspec.yaml` | `device_calendar`, `permission_handler` 추가 |
| Delete | `lib/features/settings/presentation/widgets/google_account_list_tile.dart` | 새 통합 섹션이 책임 흡수 |

## CalendarTarget 모델

```dart
enum CalendarTarget {
  none,
  google,
  device;

  String get prefValue => name;

  static CalendarTarget fromValue(String? v) {
    return values.firstWhere(
      (t) => t.name == v,
      orElse: () => CalendarTarget.none,
    );
  }
}
```

기본값 `none`. 신규/기존 사용자 모두 처음에는 미설정 상태로 시작 → 사용자가 설정에서 명시 선택.

## 슬라이드 핸들러 통합

```dart
Future<void> _onSaveToCalendar(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) async {
  final target = ref.read(calendarTargetProvider);
  switch (target) {
    case CalendarTarget.none:
      _showSetupNeededSnack(context);
      return;
    case CalendarTarget.google:
      await _saveToGoogle(context, ref, event);
    case CalendarTarget.device:
      await _saveToDevice(context, ref, event);
  }
}
```

## 동적 라벨 적용

| 영역 | none | google | device |
|------|------|--------|--------|
| 우측 스와이프 활성 | ✗ | ✓ | ✓ |
| 슬라이드 background 라벨 | — | `Google 저장` | `기기 저장` |
| 슬라이드 힌트 바 | 숨김 | `오른쪽으로 밀기 — Google 저장` | `오른쪽으로 밀기 — 기기 저장` |
| 저장 성공 SnackBar | — | `Google 캘린더에 저장했습니다` | `기기 캘린더에 저장했습니다` |
| 중복 저장 안내 | — | `이미 저장된 일정입니다` | `이미 저장된 일정입니다` |

문자열은 신규 `CalendarIntegrationStrings`에 통합.

## 설정 화면 구성

기존 "구글 계정" 섹션을 "캘린더 연동"으로 일반화. 라디오로 target 선택 + target에
따라 활성 상세(계정 정보 / 권한 상태)를 그 아래에 표시.

**상태별 UI**:

```
[캘린더 연동]
  연동 대상      사용 안 함  ▾
```

```
[캘린더 연동]
  연동 대상      Google 캘린더 ▾
  ─────────────────────────────────
  bery97@gmail.com         [로그아웃]
```

```
[캘린더 연동]
  연동 대상      기기 캘린더 ▾
  ─────────────────────────────────
  ✓ 캘린더 권한 허용됨
```

```
[캘린더 연동]
  연동 대상      기기 캘린더 ▾
  ─────────────────────────────────
  ⚠ 캘린더 권한이 필요합니다  [설정에서 켜기]
```

라디오는 바텀시트로 노출. iOS 표준 라디오 다이얼로그 패턴.

## DB v5 마이그레이션

```sql
ALTER TABLE calendar_events ADD COLUMN device_event_id TEXT;
```

`DatabaseHelper._onUpgrade`의 v4→v5 분기에 한 줄. 기존 사용자 데이터 그대로 유지.
`CalendarEvent` 모델에 `deviceEventId` 필드 + `fromMap`/`toMap` 양방향 변환 추가.

## 권한 처리

- 첫 슬라이드 시 device_calendar의 `hasPermissions()` → false면 `requestPermissions()`
- iOS는 `NSCalendarsUsageDescription` 다이얼로그 자동 노출
- Android는 `READ_CALENDAR`/`WRITE_CALENDAR` 다이얼로그 자동 노출
- 거부 시 `permission_handler.openAppSettings()`로 설정 앱 직접 이동
- 설정 탭의 권한 상태는 `devicePermissionProvider`가 watch — 화면 진입 시마다 갱신

## 엣지 케이스

| 상황 | 처리 |
|------|------|
| 신규 사용자(처음 설치) | `calendar_target` 키 없음 → enum default `none` |
| 기존 사용자(Google 토글로 사용 중) | 키 없음 → `none` 시작. 사용자가 설정에서 Google 다시 선택 (일회성 마찰) |
| target=none + 우측 스와이프 시도 | 슬라이드 자체 비활성. 슬라이드 힌트 바도 숨김 |
| 기기 권한 미허용 + 기기 슬라이드 | SnackBar `[설정 열기]`. 라디오 선택은 유지 |
| 권한 허용 후 OS 설정에서 다시 거부 | 다음 슬라이드 시 동일 SnackBar |
| 같은 이벤트 재슬라이드 | `device_event_id` 있으면 update. update 실패(이벤트 OS에서 삭제됨) → insert 재시도 (Google과 동일) |
| target을 google→device로 전환 | 기존 `google_event_id`/`device_event_id` 그대로 보존. 다음 슬라이드부터 새 target에 저장 |
| iCloud 캘린더 비활성 기기 | device_calendar의 첫 번째 calendar에 자동 저장 (보통 "On My iPhone") |
| Android에서 Google 계정만 등록된 경우 | 첫 번째 calendar = 사용자 Google 계정 → 결과적으로 Google 캘린더에 저장됨. target=google과 결과 동일하지만 OAuth 동의 불필요 |

## 테스트 계획

### DeviceCalendarService 단위 테스트
서비스에 인터페이스(`DeviceCalendarApi`) 분리 + fake 구현으로 테스트.
- 권한 허용/거부 분기
- createEvent 정상 흐름
- updateEvent → 이벤트 없으면 insert로 fallback
- 양 OS 동작은 device_calendar 패키지가 보장 → 우리 래퍼는 인터페이스만 검증

### CalendarTarget 직렬화 테스트
- enum ↔ String 양방향 변환
- 알 수 없는 값은 none으로 fallback

### Repository 테스트
- `updateDeviceEventId` 정상 동작
- 활성 일정 조회 결과에 `deviceEventId` 포함

### 통합 테스트
- 시뮬레이터에서 권한 다이얼로그 + 저장 흐름은 사람 눈으로 검증
- 자동 통합 테스트 추가는 안 함 (기존 11 시나리오 회귀만 통과)

## 의도적으로 다루지 않는 항목

- **Apple/Google 두 캘린더 동시 저장** — 단일 선택 정책. 추후 사용자 요청 시 확장
- **저장할 캘린더 선택 UI** — 1차에는 기본 캘린더에 자동. 추후 필요 시 추가
- **양방향 동기화** — 단방향만. Google 정책과 동일
- **알림** — 시스템 캘린더에 저장된 후의 OS 알림은 사용자 OS 설정 책임. 본 앱 알림은 별도 (notification_rules) 그대로
- **AppFeatures.deviceCalendarEnabled 플래그** — 외부 verification 같은 외부 조건이 없으므로 플래그 추가 안 함. 기본 활성

## 출시 영향

- DB 스키마 v4 → v5 (한 컬럼 추가, 마이그레이션 부담 작음)
- 기존 사용자 데이터 그대로 호환
- iOS Info.plist에 새 키 추가 → 첫 슬라이드 시 권한 다이얼로그 노출
- 1.0.x 또는 1.1.0 패치로 배포 가능 (이름 결정은 출시 시점에)
