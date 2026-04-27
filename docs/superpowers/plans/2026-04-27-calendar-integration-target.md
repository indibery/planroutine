# 캘린더 연동 대상 선택 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 캘린더 외부 저장 대상을 Google ↔ 기기 캘린더 ↔ 사용 안 함 중에서 사용자가 단일 선택할 수 있는 옵션을 추가.

**Architecture:** `device_calendar` 패키지로 iOS EventKit / Android CalendarContract 추상화. `CalendarTarget` enum + SharedPreferences-backed provider가 단일 source of truth. 캘린더 화면 슬라이드 핸들러가 target에 따라 GoogleCalendarService / DeviceCalendarService로 분기. 설정 탭의 기존 "구글 계정" 섹션을 "캘린더 연동" 섹션으로 통합.

**Tech Stack:** `device_calendar`, `permission_handler` 신규. 기존 google_sign_in/googleapis/sqflite/Riverpod 그대로.

**Spec:** `docs/superpowers/specs/2026-04-27-calendar-integration-target-design.md`

---

## File Structure

| 종류 | 경로 | 책임 |
|------|------|------|
| Modify | `pubspec.yaml` | `device_calendar`, `permission_handler` 의존성 추가 |
| Modify | `ios/Runner/Info.plist` | `NSCalendarsUsageDescription` 키 추가 |
| Modify | `android/app/src/main/AndroidManifest.xml` | `READ_CALENDAR`, `WRITE_CALENDAR` 권한 추가 |
| Modify | `lib/core/database/database_helper.dart` | v5 마이그레이션: `device_event_id` 컬럼 추가 |
| Modify | `lib/features/calendar/domain/calendar_event.dart` | `deviceEventId` 필드 추가 (freezed 재생성) |
| Modify | `lib/features/calendar/data/calendar_repository.dart` | `updateDeviceEventId` 메서드 추가 |
| Create | `lib/features/settings/presentation/providers/calendar_target_provider.dart` | enum + SharedPreferences-backed AsyncNotifier |
| Create | `lib/features/device_calendar/data/device_calendar_service.dart` | `device_calendar` 패키지 래퍼. 권한/CRUD |
| Create | `lib/features/device_calendar/presentation/providers/device_calendar_providers.dart` | service provider, 권한 상태 provider |
| Create | `lib/core/constants/strings/calendar_integration_strings.dart` | 라디오/슬라이드/SnackBar 라벨 |
| Create | `lib/features/settings/presentation/widgets/calendar_integration_section.dart` | 통합 섹션 위젯 |
| Modify | `lib/features/calendar/presentation/screens/calendar_screen.dart` | `_onSaveToCalendar`로 통합, target 분기 |
| Modify | `lib/features/calendar/presentation/widgets/event_list_section.dart` | 슬라이드 background 라벨 동적화 |
| Modify | `lib/features/calendar/presentation/widgets/calendar_slide_hint_bar.dart` | target 분기로 라벨/숨김 |
| Modify | `lib/features/settings/presentation/screens/settings_screen.dart` | `GoogleAccountListTile` → `CalendarIntegrationSection` |
| Delete | `lib/features/settings/presentation/widgets/google_account_list_tile.dart` | 통합 섹션이 책임 흡수 |

---

### Task 1: 의존성 + 플랫폼 권한 추가

**Files:**
- Modify: `pubspec.yaml`
- Modify: `ios/Runner/Info.plist`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: pubspec.yaml 의존성 추가**

`http: ^1.2.2` 라인 다음(현재 line 58)에 추가:

```yaml
  # 시스템 캘린더(iOS EventKit / Android CalendarContract) 통합
  device_calendar: ^4.3.3
  # OS 캘린더 권한 요청 + 거부 시 설정 앱 직접 이동
  permission_handler: ^11.3.1
```

- [ ] **Step 2: pub get 실행**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter pub get`

Expected: 의존성 정상 설치, "Got dependencies!" 메시지

- [ ] **Step 3: iOS Info.plist에 권한 문구 추가**

`ios/Runner/Info.plist`의 `</dict>` 직전에 추가:

```xml
	<key>NSCalendarsUsageDescription</key>
	<string>일정을 iOS 캘린더 앱에 저장하기 위해 캘린더 접근 권한이 필요합니다.</string>
```

- [ ] **Step 4: AndroidManifest.xml에 권한 추가**

`android/app/src/main/AndroidManifest.xml`의 최상단 `<manifest>` 안, `<application>` 직전에 추가:

```xml
    <!-- 시스템 캘린더 이벤트 저장(device_calendar 패키지) -->
    <uses-permission android:name="android.permission.READ_CALENDAR" />
    <uses-permission android:name="android.permission.WRITE_CALENDAR" />
```

- [ ] **Step 5: analyze + iOS pod install**

Run:
```bash
cd /Users/kwangsukim/i_code/planroutine && flutter analyze && (cd ios && pod install)
```

Expected: analyze 깨끗, pod install 정상 (device_calendar/permission_handler iOS 부분 추가)

- [ ] **Step 6: 커밋**

```bash
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist ios/Podfile.lock android/app/src/main/AndroidManifest.xml
git commit -m "$(cat <<'EOF'
chore(deps): device_calendar + permission_handler 추가

iOS NSCalendarsUsageDescription, Android READ/WRITE_CALENDAR 권한 명세.
Apple/Android 시스템 캘린더 통합 기반.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: DB v5 마이그레이션 + CalendarEvent 모델 deviceEventId

**Files:**
- Modify: `lib/core/database/database_helper.dart`
- Modify: `lib/features/calendar/domain/calendar_event.dart`
- Test: `test/features/calendar/domain/calendar_event_test.dart` (확장)

- [ ] **Step 1: DB 버전 업 + 마이그레이션 분기 추가**

`database_helper.dart` 라인 17:

변경 전:
```dart
  static const _databaseVersion = 4;
```
변경 후:
```dart
  static const _databaseVersion = 5;
```

`_onUpgrade` 메서드(라인 51) 끝에 v4→v5 추가. 변경 전:

```dart
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE $tableCalendarEvents ADD COLUMN google_event_id TEXT',
      );
    }
  }
```

변경 후:

```dart
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE $tableCalendarEvents ADD COLUMN google_event_id TEXT',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE $tableCalendarEvents ADD COLUMN device_event_id TEXT',
      );
    }
  }
```

또 `_onCreate`의 `CREATE TABLE $tableCalendarEvents` 안 `google_event_id TEXT,` 라인(123) 다음에 한 줄 추가:

```sql
        device_event_id TEXT,
```

상단 주석(라인 49)에 v4→v5 설명 추가:
```dart
  /// v4 → v5: 기기 캘린더(device_calendar) 중복 방지. calendar_events에
  /// [device_event_id] 컬럼 추가. NULL = 미저장, 값 있으면 재저장 시 update.
```

- [ ] **Step 2: CalendarEvent 모델에 deviceEventId 필드 추가**

`lib/features/calendar/domain/calendar_event.dart`의 freezed 생성자에서 `googleEventId` 다음 줄(라인 25 근처)에 한 줄 추가:

```dart
    @JsonKey(name: 'device_event_id') String? deviceEventId,
```

`fromMap` 팩토리(라인 32~)의 `googleEventId:` 다음에 추가:
```dart
      deviceEventId: map['device_event_id'] as String?,
```

`toMap`(라인 50~)의 `'google_event_id': googleEventId,` 다음에 추가:
```dart
      'device_event_id': deviceEventId,
```

- [ ] **Step 3: build_runner로 freezed/json 파일 재생성**

Run: `cd /Users/kwangsukim/i_code/planroutine && dart run build_runner build --delete-conflicting-outputs`

Expected: 정상 완료, `calendar_event.freezed.dart`/`calendar_event.g.dart`에 `deviceEventId` 자동 반영

- [ ] **Step 4: 모델 라운드트립 테스트 추가**

`test/features/calendar/domain/calendar_event_test.dart` 마지막 group 직전 또는 적절한 위치에 추가:

```dart
  group('deviceEventId 라운드트립', () {
    test('toMap → fromMap에서 deviceEventId 보존', () {
      final event = CalendarEvent(
        id: 1,
        title: '테스트',
        eventDate: '2026-05-15',
        deviceEventId: 'EKE-12345',
        createdAt: '2026-04-27T10:00:00.000',
        updatedAt: '2026-04-27T10:00:00.000',
      );
      final map = event.toMap();
      expect(map['device_event_id'], 'EKE-12345');

      final restored = CalendarEvent.fromMap({
        ...map,
        // toMap이 id를 포함하므로 fromMap에서 다시 읽음
      });
      expect(restored.deviceEventId, 'EKE-12345');
    });

    test('device_event_id가 NULL이면 fromMap에서 null', () {
      final map = {
        'title': '테스트',
        'event_date': '2026-05-15',
        'is_all_day': 1,
        'device_event_id': null,
        'created_at': '2026-04-27T10:00:00.000',
        'updated_at': '2026-04-27T10:00:00.000',
      };
      final event = CalendarEvent.fromMap(map);
      expect(event.deviceEventId, isNull);
    });
  });
```

- [ ] **Step 5: 테스트 실행**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/calendar/domain/calendar_event_test.dart`

Expected: 모든 테스트 통과 (기존 + 신규 2개)

- [ ] **Step 6: 커밋**

```bash
git add lib/core/database/database_helper.dart lib/features/calendar/domain/calendar_event.dart lib/features/calendar/domain/calendar_event.freezed.dart lib/features/calendar/domain/calendar_event.g.dart test/features/calendar/domain/calendar_event_test.dart
git commit -m "$(cat <<'EOF'
feat(db): v5 마이그레이션 — calendar_events.device_event_id 컬럼

기기 캘린더(device_calendar) 중복 방지용 id 보관. CalendarEvent 모델
freezed 재생성 + 양방향 변환 + 라운드트립 테스트.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: CalendarRepository.updateDeviceEventId

**Files:**
- Modify: `lib/features/calendar/data/calendar_repository.dart`
- Test: `test/features/calendar/data/calendar_repository_test.dart`

- [ ] **Step 1: 실패 테스트 작성**

`calendar_repository_test.dart`의 마지막 group 직전 또는 적절한 위치에 추가:

```dart
  group('updateDeviceEventId', () {
    test('지정한 이벤트의 device_event_id 갱신', () async {
      final eventId = await repo.createEvent(
        CalendarEvent(
          title: '테스트',
          eventDate: '2026-05-15',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );

      await repo.updateDeviceEventId(eventId, 'EKE-99999');

      final events = await repo.getEventsByMonth(2026, 5);
      expect(events.first.deviceEventId, 'EKE-99999');
    });
  });
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/calendar/data/calendar_repository_test.dart`

Expected: FAIL — `updateDeviceEventId` 메서드 없음

- [ ] **Step 3: 메서드 구현**

`calendar_repository.dart`의 `updateGoogleEventId` 메서드(라인 70~) 바로 아래에 추가:

```dart
  /// 기기 캘린더에 저장된 이벤트의 [deviceEventId]를 기록.
  /// 다음 "기기 저장" 스와이프에서 update로 처리해 중복 생성 방지.
  Future<int> updateDeviceEventId(int id, String deviceEventId) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableCalendarEvents,
      {
        'device_event_id': deviceEventId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
```

- [ ] **Step 4: 통과 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/calendar/data/calendar_repository_test.dart`

Expected: PASS — 신규 1 + 기존 모두 통과

- [ ] **Step 5: 커밋**

```bash
git add lib/features/calendar/data/calendar_repository.dart test/features/calendar/data/calendar_repository_test.dart
git commit -m "$(cat <<'EOF'
feat(calendar): updateDeviceEventId — 기기 이벤트 id 보관

스와이프 재시도 시 update로 처리해 중복 생성 방지(Google과 동일 패턴).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: CalendarTarget enum + provider

**Files:**
- Create: `lib/features/settings/presentation/providers/calendar_target_provider.dart`
- Test: `test/features/settings/calendar_target_provider_test.dart`

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/settings/calendar_target_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/settings/presentation/providers/calendar_target_provider.dart';

void main() {
  group('CalendarTarget 직렬화', () {
    test('알려진 enum 값 round-trip', () {
      for (final t in CalendarTarget.values) {
        expect(CalendarTarget.fromValue(t.prefValue), t);
      }
    });

    test('null 또는 unknown 값은 none', () {
      expect(CalendarTarget.fromValue(null), CalendarTarget.none);
      expect(CalendarTarget.fromValue(''), CalendarTarget.none);
      expect(CalendarTarget.fromValue('outlook'), CalendarTarget.none);
    });

    test('prefValue는 enum name과 동일', () {
      expect(CalendarTarget.none.prefValue, 'none');
      expect(CalendarTarget.google.prefValue, 'google');
      expect(CalendarTarget.device.prefValue, 'device');
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/settings/calendar_target_provider_test.dart`

Expected: FAIL — 모듈 없음

- [ ] **Step 3: 모듈 구현**

```dart
// lib/features/settings/presentation/providers/calendar_target_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 캘린더 외부 저장 대상.
enum CalendarTarget {
  none,
  google,
  device;

  String get prefValue => name;

  static CalendarTarget fromValue(String? v) {
    if (v == null || v.isEmpty) return CalendarTarget.none;
    return values.firstWhere(
      (t) => t.name == v,
      orElse: () => CalendarTarget.none,
    );
  }
}

/// SharedPreferences 키.
const _prefKey = 'calendar_target';

/// 현재 선택된 캘린더 연동 대상. SharedPreferences에 영속.
final calendarTargetProvider =
    AsyncNotifierProvider<CalendarTargetNotifier, CalendarTarget>(
  CalendarTargetNotifier.new,
);

class CalendarTargetNotifier extends AsyncNotifier<CalendarTarget> {
  @override
  Future<CalendarTarget> build() async {
    final prefs = await SharedPreferences.getInstance();
    return CalendarTarget.fromValue(prefs.getString(_prefKey));
  }

  /// 사용자 선택 변경 → SharedPreferences에 저장 + 상태 갱신.
  Future<void> setTarget(CalendarTarget target) async {
    state = AsyncData(target);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, target.prefValue);
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/settings/calendar_target_provider_test.dart`

Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/features/settings/presentation/providers/calendar_target_provider.dart test/features/settings/calendar_target_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(settings): CalendarTarget enum + SharedPreferences provider

none/google/device 단일 선택. AsyncNotifierProvider로 영속 + 상태 관리.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: DeviceCalendarService + provider

**Files:**
- Create: `lib/features/device_calendar/data/device_calendar_service.dart`
- Create: `lib/features/device_calendar/presentation/providers/device_calendar_providers.dart`

권한 흐름은 device_calendar 패키지 + permission_handler 함께 사용. 단위 테스트는 플랫폼 채널 의존이라 추가하지 않음 (인터페이스만 검증). UI 통합 검증은 TestFlight에서.

- [ ] **Step 1: DeviceCalendarService 구현**

```dart
// lib/features/device_calendar/data/device_calendar_service.dart
import 'package:device_calendar/device_calendar.dart';

/// 시스템 캘린더(iOS EventKit / Android CalendarContract) 통합 래퍼.
///
/// 단방향 동기화: 플랜루틴에서 만든 이벤트를 사용자 기기의 기본 캘린더로
/// **생성/갱신**한다. 양방향 동기화는 안 함.
class DeviceCalendarService {
  DeviceCalendarService() : _plugin = DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  /// 캘린더 권한 보유 여부.
  Future<bool> hasPermissions() async {
    final result = await _plugin.hasPermissions();
    return result.data ?? false;
  }

  /// 권한 요청. 사용자가 거부하면 false 반환.
  Future<bool> requestPermissions() async {
    final result = await _plugin.requestPermissions();
    return result.data ?? false;
  }

  /// 이벤트 생성 또는 갱신. [existingId]가 있으면 update, 없으면 create.
  /// update 실패(이벤트가 OS에서 삭제됨)면 새로 create.
  /// 반환: device 측 event id (이후 update 용도로 보관).
  Future<String> saveEvent({
    String? existingId,
    required String title,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final calendarId = await _resolveDefaultCalendarId();
    if (calendarId == null) {
      throw const DeviceCalendarException('writable 캘린더가 없습니다');
    }

    final event = Event(
      calendarId,
      eventId: existingId,
      title: title,
      description: description,
      start: TZDateTime.from(startDate, _localLocation()),
      end: TZDateTime.from(endDate ?? startDate, _localLocation()),
      allDay: true,
    );

    final result = await _plugin.createOrUpdateEvent(event);
    if (result?.isSuccess != true || result?.data == null) {
      // existingId가 stale일 수 있으므로 한 번 더 (eventId 비우고) create 재시도
      if (existingId != null) {
        return saveEvent(
          existingId: null,
          title: title,
          description: description,
          startDate: startDate,
          endDate: endDate,
        );
      }
      throw DeviceCalendarException(
        result?.errors.map((e) => e.errorMessage).join(', ') ??
            '이벤트 저장 실패',
      );
    }
    return result!.data!;
  }

  /// 기본 쓰기 가능 캘린더 id. isDefault==true 우선, 없으면 첫 번째 writable.
  Future<String?> _resolveDefaultCalendarId() async {
    final result = await _plugin.retrieveCalendars();
    final calendars = result.data;
    if (calendars == null || calendars.isEmpty) return null;

    final writable = calendars.where((c) => c.isReadOnly == false).toList();
    if (writable.isEmpty) return null;

    return writable.firstWhere(
      (c) => c.isDefault == true,
      orElse: () => writable.first,
    ).id;
  }

  /// 로컬 타임존. 알림 모듈에서 이미 timezone 초기화돼 있으므로 local 사용.
  Location _localLocation() => local;
}

class DeviceCalendarException implements Exception {
  const DeviceCalendarException(this.message);
  final String message;
  @override
  String toString() => 'DeviceCalendarException: $message';
}
```

- [ ] **Step 2: provider 모듈 구현**

```dart
// lib/features/device_calendar/presentation/providers/device_calendar_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/device_calendar_service.dart';

/// 시스템 캘린더 서비스 싱글톤.
final deviceCalendarServiceProvider = Provider<DeviceCalendarService>((ref) {
  return DeviceCalendarService();
});

/// 캘린더 권한 상태. 화면 진입/refresh 시마다 갱신.
final devicePermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(deviceCalendarServiceProvider);
  return service.hasPermissions();
});
```

- [ ] **Step 3: 알림 모듈에서 timezone 초기화 확인**

알림 모듈이 이미 `tz.initializeTimeZones()`를 호출하므로 device_calendar의 `local` Location 사용 가능. 별도 init 불필요. 다만 만약 timezone init 시점이 device_calendar 호출 후일 가능성은 main.dart에서 확인:

Run: `cd /Users/kwangsukim/i_code/planroutine && grep -n "initializeTimeZones\|tz\.local" lib/main.dart lib/features/notifications/data/*.dart`

Expected: `initializeTimeZones`가 main.dart 또는 notification_service.dart 부팅 시점에 호출됨

(이미 `flutter_local_notifications`가 timezone 초기화를 강제하므로 보장됨)

- [ ] **Step 4: analyze**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze`

Expected: PASS, 새 경고 없음

- [ ] **Step 5: 커밋**

```bash
git add lib/features/device_calendar/
git commit -m "$(cat <<'EOF'
feat(device_calendar): DeviceCalendarService + providers

device_calendar 패키지 래퍼. saveEvent는 existingId 있으면 update,
update 실패 시 create로 fallback(Google과 동일 패턴). 기본 writable
캘린더 자동 선택.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: CalendarIntegrationStrings

**Files:**
- Create: `lib/core/constants/strings/calendar_integration_strings.dart`

- [ ] **Step 1: 모듈 구현**

```dart
// lib/core/constants/strings/calendar_integration_strings.dart

/// 캘린더 연동(외부 저장 대상 선택) 관련 문자열.
class CalendarIntegrationStrings {
  CalendarIntegrationStrings._();

  // 설정 섹션
  static const sectionTitle = '캘린더 연동';
  static const targetLabel = '연동 대상';
  static const targetNone = '사용 안 함';
  static const targetGoogle = 'Google 캘린더';
  static const targetDevice = '기기 캘린더';

  // 권한 안내
  static const permissionGranted = '캘린더 권한 허용됨';
  static const permissionDenied = '캘린더 권한이 필요합니다';
  static const openSettings = '설정에서 켜기';

  // 슬라이드 라벨/힌트 — target에 따라 분기
  static const swipeSaveGoogle = 'Google 저장';
  static const swipeSaveDevice = '기기 저장';
  static const swipeHintGoogle = '오른쪽으로 밀기 — Google 저장';
  static const swipeHintDevice = '오른쪽으로 밀기 — 기기 저장';

  // SnackBar
  static const setupNeeded = '캘린더 연동을 먼저 설정해주세요';
  static const savedGoogle = 'Google 캘린더에 저장했습니다';
  static const savedDevice = '기기 캘린더에 저장했습니다';
  static const alreadySaved = '이미 저장된 일정입니다';
  static const saveFailed = '저장 실패';
}
```

- [ ] **Step 2: app_strings.dart의 barrel export에 추가**

`lib/core/constants/app_strings.dart` 상단의 export 라인 옆에 추가:

```dart
export 'strings/calendar_integration_strings.dart';
```

(다른 strings 파일이 export되어 있는 패턴을 따라 같은 위치에)

- [ ] **Step 3: analyze**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze`

Expected: PASS

- [ ] **Step 4: 커밋**

```bash
git add lib/core/constants/strings/calendar_integration_strings.dart lib/core/constants/app_strings.dart
git commit -m "$(cat <<'EOF'
feat(strings): CalendarIntegrationStrings 신규

라디오/권한/슬라이드/SnackBar 라벨. target에 따른 분기 라벨 포함.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: CalendarIntegrationSection 위젯

**Files:**
- Create: `lib/features/settings/presentation/widgets/calendar_integration_section.dart`

기존 `GoogleAccountListTile`이 하던 로그인/로그아웃 + 신규 라디오 + 권한 상태를 한 섹션에 통합.

- [ ] **Step 1: 위젯 구현**

```dart
// lib/features/settings/presentation/widgets/calendar_integration_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../device_calendar/presentation/providers/device_calendar_providers.dart';
import '../../../google/presentation/providers/google_providers.dart';
import '../providers/calendar_target_provider.dart';
import 'settings_section.dart';

/// 외부 캘린더 연동 대상 단일 선택 + 활성 상세(Google 계정 / 기기 권한).
class CalendarIntegrationSection extends ConsumerWidget {
  const CalendarIntegrationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetAsync = ref.watch(calendarTargetProvider);
    final target = targetAsync.valueOrNull ?? CalendarTarget.none;

    return SettingsSection(
      title: CalendarIntegrationStrings.sectionTitle,
      children: [
        ListTile(
          leading: const Icon(Icons.event_note_outlined,
              color: AppColors.primary),
          title: const Text(CalendarIntegrationStrings.targetLabel),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_targetLabel(target)),
              const Icon(Icons.expand_more),
            ],
          ),
          onTap: () => _showTargetSheet(context, ref, target),
        ),
        if (target == CalendarTarget.google) const _GoogleAccountRow(),
        if (target == CalendarTarget.device) const _DevicePermissionRow(),
      ],
    );
  }

  String _targetLabel(CalendarTarget t) {
    switch (t) {
      case CalendarTarget.none:
        return CalendarIntegrationStrings.targetNone;
      case CalendarTarget.google:
        return CalendarIntegrationStrings.targetGoogle;
      case CalendarTarget.device:
        return CalendarIntegrationStrings.targetDevice;
    }
  }

  Future<void> _showTargetSheet(
    BuildContext context,
    WidgetRef ref,
    CalendarTarget current,
  ) async {
    final selected = await showModalBottomSheet<CalendarTarget>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in CalendarTarget.values)
              RadioListTile<CalendarTarget>(
                title: Text(_targetLabel(t)),
                value: t,
                groupValue: current,
                onChanged: (v) => Navigator.of(ctx).pop(v),
              ),
          ],
        ),
      ),
    );
    if (selected != null && selected != current) {
      await ref.read(calendarTargetProvider.notifier).setTarget(selected);
    }
  }
}

/// Google 선택 시: 로그인 상태에 따라 다른 row.
class _GoogleAccountRow extends ConsumerWidget {
  const _GoogleAccountRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(googleAccountProvider);
    final account = accountAsync.valueOrNull;

    if (account == null) {
      return ListTile(
        leading: const Icon(Icons.account_circle_outlined,
            color: AppColors.primary),
        title: const Text(GoogleStrings.signIn),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await ref.read(googleSignInActionProvider).signIn();
        },
      );
    }
    return ListTile(
      leading: account.photoUrl != null
          ? CircleAvatar(
              backgroundImage: NetworkImage(account.photoUrl!),
              backgroundColor: AppColors.surfaceVariant,
            )
          : const Icon(Icons.account_circle, color: AppColors.primary),
      title: Text(account.displayName ?? account.email),
      subtitle: Text(account.email),
      trailing: TextButton(
        onPressed: () =>
            ref.read(googleSignInActionProvider).signOut(),
        child: const Text(GoogleStrings.signOut),
      ),
    );
  }
}

/// 기기 캘린더 선택 시: 권한 상태 표시 + 거부 시 설정 버튼.
class _DevicePermissionRow extends ConsumerWidget {
  const _DevicePermissionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permAsync = ref.watch(devicePermissionProvider);
    final granted = permAsync.valueOrNull ?? false;

    if (granted) {
      return const ListTile(
        leading: Icon(Icons.check_circle, color: AppColors.inkGreen),
        title: Text(CalendarIntegrationStrings.permissionGranted),
      );
    }
    return ListTile(
      leading: const Icon(Icons.warning_amber,
          color: AppColors.gold),
      title: const Text(CalendarIntegrationStrings.permissionDenied),
      trailing: TextButton(
        onPressed: () async {
          await openAppSettings();
          // 화면 복귀 시 권한 상태 다시 조회
          ref.invalidate(devicePermissionProvider);
        },
        child: const Text(CalendarIntegrationStrings.openSettings),
      ),
    );
  }
}
```

- [ ] **Step 2: googleSignInActionProvider 시그니처 확인**

기존 `google_account_list_tile.dart`에서 Google 로그인/로그아웃을 어떻게 호출했는지 확인:

Run: `cd /Users/kwangsukim/i_code/planroutine && grep -n "signIn\|signOut\|googleAccountProvider" lib/features/google/presentation/providers/google_providers.dart lib/features/settings/presentation/widgets/google_account_list_tile.dart`

기존 패턴(예: `_signIn(context, ref)` 헬퍼 함수)이라면 그 패턴을 본 위젯에서도 동일하게 따른다. 만약 위 코드의 `googleSignInActionProvider`가 존재하지 않는 이름이면 기존 헬퍼 호출 방식으로 변경:

```dart
// 예: 기존 google_account_list_tile.dart에서 _signIn(context, ref) 형태였다면
onTap: () => _GoogleAccountRow._signInLegacy(context, ref),
```

(이 step은 실제 코드 확인 후 한 번에 작성)

- [ ] **Step 3: analyze**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze`

Expected: PASS, 새 경고 없음. (만약 googleSignInActionProvider 없으면 라인 수정)

- [ ] **Step 4: 커밋**

```bash
git add lib/features/settings/presentation/widgets/calendar_integration_section.dart
git commit -m "$(cat <<'EOF'
feat(settings): CalendarIntegrationSection 신규

라디오 + Google 계정 row + 기기 권한 row 통합. 바텀시트로 단일
선택. 권한 거부 시 [설정에서 켜기] 버튼 → permission_handler.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: settings_screen 통합 — 기존 GoogleAccountListTile 교체

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Delete: `lib/features/settings/presentation/widgets/google_account_list_tile.dart`

- [ ] **Step 1: settings_screen.dart에서 import + 사용처 교체**

`settings_screen.dart` 상단에서:

변경 전:
```dart
import '../widgets/google_account_list_tile.dart';
```
변경 후:
```dart
import '../widgets/calendar_integration_section.dart';
```

본문에서 `GoogleAccountListTile()` 호출(또는 그것을 감싸는 SettingsSection 호출 영역) 통째로 `CalendarIntegrationSection()`로 교체. AppFeatures.googleCalendarEnabled 분기는 유지하되, 이제 `CalendarIntegrationSection` 자체가 두 케이스(Google/기기) 모두 다루므로 분기 단순화:

기존 (예시):
```dart
if (AppFeatures.googleCalendarEnabled) const GoogleAccountListTile(),
```
변경 후:
```dart
if (AppFeatures.googleCalendarEnabled) const CalendarIntegrationSection(),
```

(AppFeatures.googleCalendarEnabled가 true이면 캘린더 연동 섹션 노출. false이면 섹션 자체 숨김 — Google verification 통과 전 안전.)

- [ ] **Step 2: 구 위젯 파일 삭제**

Run: `rm /Users/kwangsukim/i_code/planroutine/lib/features/settings/presentation/widgets/google_account_list_tile.dart`

- [ ] **Step 3: analyze + 회귀 테스트**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze && flutter test`

Expected: PASS, 미사용 import 경고 없음, 모든 테스트 통과

- [ ] **Step 4: 커밋**

```bash
git add lib/features/settings/presentation/screens/settings_screen.dart lib/features/settings/presentation/widgets/google_account_list_tile.dart
git commit -m "$(cat <<'EOF'
refactor(settings): GoogleAccountListTile → CalendarIntegrationSection

기존 구글 계정 단독 섹션을 캘린더 연동 통합 섹션으로 교체.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: 캘린더 슬라이드 핸들러 통합

**Files:**
- Modify: `lib/features/calendar/presentation/screens/calendar_screen.dart`

기존 `_onSaveToGoogle`을 `_onSaveToCalendar`로 일반화. target에 따라 GoogleCalendarService / DeviceCalendarService로 분기. SnackBar/저장 결과 처리도 target별 라벨.

- [ ] **Step 1: import 추가**

`calendar_screen.dart` 상단에 추가:

```dart
import 'package:permission_handler/permission_handler.dart';
import '../../../device_calendar/data/device_calendar_service.dart';
import '../../../device_calendar/presentation/providers/device_calendar_providers.dart';
import '../../../settings/presentation/providers/calendar_target_provider.dart';
```

- [ ] **Step 2: 슬라이드 핸들러 콜백 분기**

calendar_screen.dart의 `EventListSection` 호출부(현재 `onEventSaveToGoogle: AppFeatures.googleCalendarEnabled ? (event) => _onSaveToGoogle(context, ref, event) : null,` 라인 79~80) 통째로 다음으로 교체:

```dart
                onEventSaveToGoogle: () {
                  if (!AppFeatures.googleCalendarEnabled) return null;
                  final target = ref.watch(calendarTargetProvider).valueOrNull;
                  if (target == null || target == CalendarTarget.none) {
                    return null;
                  }
                  return (event) => _onSaveToCalendar(context, ref, event);
                }(),
```

(즉시 호출 함수로 target에 따라 콜백 활성/비활성 결정)

- [ ] **Step 3: _onSaveToCalendar 통합 핸들러 + _onSaveToDevice 신규 메서드 추가**

`calendar_screen.dart`의 `_onSaveToGoogle` 메서드(라인 200~) 위에 추가:

```dart
  /// 우측 스와이프 — target에 따라 Google/기기 분기.
  Future<void> _onSaveToCalendar(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final target =
        ref.read(calendarTargetProvider).valueOrNull ?? CalendarTarget.none;
    switch (target) {
      case CalendarTarget.none:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(CalendarIntegrationStrings.setupNeeded),
        ));
      case CalendarTarget.google:
        await _onSaveToGoogle(context, ref, event);
      case CalendarTarget.device:
        await _onSaveToDevice(context, ref, event);
    }
  }

  /// 기기 캘린더 저장 — 권한 확인 → save → device_event_id 보관.
  Future<void> _onSaveToDevice(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final service = ref.read(deviceCalendarServiceProvider);

    // 권한 확인. 미허용이면 요청 → 그래도 거부면 SnackBar [설정 열기]
    var granted = await service.hasPermissions();
    if (!granted) granted = await service.requestPermissions();
    if (!granted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(CalendarIntegrationStrings.permissionDenied),
        action: SnackBarAction(
          label: CalendarIntegrationStrings.openSettings,
          onPressed: () async {
            await openAppSettings();
            ref.invalidate(devicePermissionProvider);
          },
        ),
      ));
      return;
    }

    try {
      final id = await service.saveEvent(
        existingId: event.deviceEventId,
        title: event.title,
        description: event.description,
        startDate: DateTime.parse(event.eventDate),
        endDate: event.endDate != null ? DateTime.parse(event.endDate!) : null,
      );

      final eventId = event.id;
      final repository = ref.read(calendarRepositoryProvider);
      if (eventId != null) {
        await repository.updateDeviceEventId(eventId, id);
        ref.invalidate(monthEventsByYearMonthProvider);
        ref.invalidate(selectedMonthEventsProvider);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(event.deviceEventId == null
            ? CalendarIntegrationStrings.savedDevice
            : CalendarIntegrationStrings.alreadySaved),
      ));
    } on DeviceCalendarException catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(CalendarIntegrationStrings.saveFailed),
      ));
    }
  }
```

- [ ] **Step 4: EventListSection의 콜백 시그니처 확인**

EventListSection이 `ValueChanged<CalendarEvent>?` 콜백을 받음 (`event_list_section.dart:31`). 즉 `(CalendarEvent) → void`. `_onSaveToCalendar`는 async이므로 callback에선 `(event) => _onSaveToCalendar(context, ref, event)`로 감싸 fire-and-forget OK.

기존 `_onSaveToGoogle` 호출부도 동일 패턴이라 그대로 유지.

- [ ] **Step 5: analyze**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze`

Expected: PASS, 새 경고 없음

- [ ] **Step 6: 커밋**

```bash
git add lib/features/calendar/presentation/screens/calendar_screen.dart
git commit -m "$(cat <<'EOF'
feat(calendar): 슬라이드 핸들러 target 분기 — Google/기기

_onSaveToCalendar로 통합. target=none이면 SnackBar 안내, device면
권한 흐름 + DeviceCalendarService.saveEvent → device_event_id 보관.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: 슬라이드 라벨 / 힌트 바 동적화

**Files:**
- Modify: `lib/features/calendar/presentation/widgets/event_list_section.dart`
- Modify: `lib/features/calendar/presentation/widgets/calendar_slide_hint_bar.dart`

- [ ] **Step 1: event_list_section의 background 라벨 동적화**

`event_list_section.dart`의 background 영역 — `googleSave != null` 분기에서 라벨이 `CalendarStrings.swipeGoogleSave`로 고정. 이를 target 기반으로 변경.

EventListSection에 신규 prop `targetLabel` 추가:

```dart
class EventListSection extends StatelessWidget {
  const EventListSection({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.onEventTap,
    required this.onEventSaveToGoogle,
    required this.onEventToggleCompleted,
    required this.targetLabel,  // 신규
  });

  // ...
  final String targetLabel;  // 'Google 저장' 또는 '기기 저장'
```

해당 위젯 build 안 background를 수정:

변경 전:
```dart
      background: googleSave != null
          ? const DismissibleBackground(
              accent: AppColors.inkGreen,
              icon: Icons.cloud_upload,
              label: CalendarStrings.swipeGoogleSave,
              alignment: Alignment.centerLeft,
              verticalMargin: AppSizes.spacing4,
            )
          : completeBackground,
```

변경 후:
```dart
      background: googleSave != null
          ? DismissibleBackground(
              accent: AppColors.inkGreen,
              icon: Icons.cloud_upload,
              label: targetLabel,
              alignment: Alignment.centerLeft,
              verticalMargin: AppSizes.spacing4,
            )
          : completeBackground,
```

- [ ] **Step 2: calendar_screen에서 targetLabel 전달**

`calendar_screen.dart`의 EventListSection 호출부에 `targetLabel`을 추가. Step 2~3에서 추가한 target 변수 활용:

```dart
                EventListSection(
                  selectedDate: date,
                  events: entry.value,
                  onEventTap: (event) => _onEditEvent(context, ref, event),
                  onEventSaveToGoogle: <위에서 추가한 즉시 호출 함수>,
                  onEventToggleCompleted: (event) => ref
                      .read(selectedMonthEventsProvider.notifier)
                      .toggleCompleted(event),
                  targetLabel: () {
                    final target = ref.watch(calendarTargetProvider).valueOrNull;
                    if (target == CalendarTarget.device) {
                      return CalendarIntegrationStrings.swipeSaveDevice;
                    }
                    return CalendarIntegrationStrings.swipeSaveGoogle;
                  }(),
                ),
```

- [ ] **Step 3: calendar_slide_hint_bar 동적화**

`calendar_slide_hint_bar.dart` 통째로 교체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_features.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/slide_hint_bar.dart' as shared;
import '../../../settings/presentation/providers/calendar_target_provider.dart';

/// 캘린더 화면 슬라이드 힌트 — target에 따라 라벨 변경/숨김.
///
/// - target == none: 힌트 바 자체 숨김 (외부 저장 슬라이드 비활성)
/// - target == google: "오른쪽으로 밀기 — Google 저장"
/// - target == device: "오른쪽으로 밀기 — 기기 저장"
class CalendarSlideHintBar extends ConsumerWidget {
  const CalendarSlideHintBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppFeatures.googleCalendarEnabled) {
      return const SizedBox.shrink();
    }

    final target =
        ref.watch(calendarTargetProvider).valueOrNull ?? CalendarTarget.none;
    if (target == CalendarTarget.none) {
      return const SizedBox.shrink();
    }

    final leftText = target == CalendarTarget.device
        ? CalendarIntegrationStrings.swipeHintDevice
        : CalendarIntegrationStrings.swipeHintGoogle;

    return shared.SlideHintBar(
      prefKey: 'calendar_slide_hint_dismissed',
      leftIcon: Icons.cloud_upload,
      leftText: leftText,
      leftColor: AppColors.inkGreen,
      rightIcon: Icons.check_circle,
      rightText: CalendarStrings.swipeHintComplete,
      rightColor: AppColors.gold,
    );
  }
}
```

- [ ] **Step 4: analyze + 회귀 테스트**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze && flutter test`

Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/features/calendar/presentation/widgets/event_list_section.dart lib/features/calendar/presentation/widgets/calendar_slide_hint_bar.dart lib/features/calendar/presentation/screens/calendar_screen.dart
git commit -m "$(cat <<'EOF'
feat(calendar): 슬라이드 라벨/힌트 바 target 분기

EventListSection.targetLabel prop 추가. SlideHintBar는 target=none
시 숨김, google/device 따라 라벨 분기. ConsumerWidget으로 변경.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: 회귀 테스트 + analyze

**Files:** 변경 없음

- [ ] **Step 1: 단위 테스트 전체 실행**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test`

Expected: PASS — 기존 + 신규 테스트(라운드트립, repository, target enum 등) 모두 통과

- [ ] **Step 2: analyze**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze`

Expected: `No issues found!`

통합 테스트는 시뮬레이터/권한 다이얼로그 의존이라 본 작업에선 단위 테스트 회귀로 갈음. 권한 흐름 + 저장 동작은 TestFlight v63에서 사람 눈으로 확인.

---

### Task 12: TestFlight 배포

**Files:** 변경 없음

CLAUDE.md의 **배포 플로우 정책** + deploy_flow 메모리에 따라 analyze + test 통과 시 사용자 승인 없이 진행.

- [ ] **Step 1: TestFlight 배포**

Run: `cd /Users/kwangsukim/i_code/planroutine && ./ios/bin/fastlane.sh beta`

Expected: build_number 자동 +1, IPA 빌드, TestFlight 업로드 성공

배포 실패 시 멈추고 사용자에 보고.

- [ ] **Step 2: 원격 push**

Run: `git push origin main`

Expected: origin/main에 본 작업의 커밋들 반영

---

## Self-Review

### Spec coverage

| Spec 요건 | 구현 Task |
|-----------|-----------|
| device_calendar 패키지 도입 | Task 1 + Task 5 |
| iOS NSCalendarsUsageDescription | Task 1 Step 3 |
| Android READ/WRITE_CALENDAR | Task 1 Step 4 |
| 단일 선택 + SharedPreferences 영속 | Task 4 |
| 설정 통합 섹션 (라디오 + 활성 상세) | Task 7 + Task 8 |
| device_event_id 컬럼 + 모델 | Task 2 |
| Repository updateDeviceEventId | Task 3 |
| DeviceCalendarService (권한/CRUD) | Task 5 |
| 슬라이드 핸들러 target 분기 | Task 9 |
| 슬라이드 라벨/힌트 동적화 | Task 10 |
| target=none 시 슬라이드 비활성 + 힌트 숨김 | Task 9 Step 2 + Task 10 Step 3 |
| 권한 거부 SnackBar [설정 열기] | Task 9 Step 3 (saveToDevice) |
| 권한 상태 설정에서 상시 표시 | Task 7 (_DevicePermissionRow) |
| 동일 이벤트 재슬라이드 update→insert fallback | Task 5 (saveEvent의 try/recurse) |
| target 전환 시 양쪽 id 보존 | Task 2 + Task 3 (DB 컬럼 분리) |
| google_account_list_tile.dart 제거 | Task 8 Step 2 |
| 회귀 + analyze | Task 11 |

모든 spec 요건이 Task에 매핑됨.

### Placeholder scan

- Task 7 Step 2의 "googleSignInActionProvider 시그니처 확인" 단계에서 기존 코드 확인 후 결정하는 부분이 살짝 가변. 단계 자체는 명확한 검증 + 수정 지시가 있어 무방.
- 그 외 "TBD"/"TODO"/"implement later" 없음. 모든 코드 step에 실제 코드.

### Type consistency

- `CalendarTarget` enum (Task 4) → Task 7/9/10 모두 `none/google/device` 동일.
- `CalendarTargetNotifier.setTarget(CalendarTarget)` (Task 4) → Task 7에서 동일 시그니처 호출.
- `DeviceCalendarService.saveEvent({existingId, title, description, startDate, endDate})` (Task 5) → Task 9의 `_onSaveToDevice`에서 동일 named arg 사용.
- `updateDeviceEventId(int id, String deviceEventId)` (Task 3) → Task 9에서 동일 시그니처 호출.
- `CalendarIntegrationStrings.swipeSave/Hint*` (Task 6) → Task 9/10에서 일치.
- `EventListSection.targetLabel: String` 신규 prop (Task 10 Step 1) → Task 10 Step 2의 호출에서 전달.

타입/시그니처 충돌 없음.
