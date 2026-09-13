# 아이폰 단축어 연계 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 공직플랜의 일정을 아이폰 단축어에서 **앱을 열지 않고** 등록하고 조회할 수 있게 만든다.

**Architecture:** App Intents를 **앱 타깃에 직접** 둔다(패키지 없음, App Extension 아님). 시스템이 앱을 백그라운드로 띄우므로 앱 샌드박스의 기존 데이터베이스에 그대로 닿고 Dart도 실행된다. Swift는 인텐트 선언과 MethodChannel 호출만 지고, 파싱·중복 체크·삽입은 기존 Dart 코드가 그대로 진다.

**Tech Stack:** Swift(App Intents, iOS 16+) · Flutter 3.44.8 / Dart 3.12.2 · Riverpod · sqflite · MethodChannel

**Spec:** `docs/superpowers/specs/2026-09-13-ios-app-intents-design.md`
(실험 근거: `.local/experiments/app-intent-백그라운드-flutter-엔진.md`, git 제외)

## Global Constraints

- **iOS 배포 타깃은 16.0이다.** App Intents의 최소 버전이며 사용자 승인을 받았다. 낮추면 인텐트가 빌드에서 조용히 빠진다.
- **Swift에 비즈니스 로직을 두지 않는다.** SQL·테이블 이름·컬럼 이름·상태값이 Swift에 등장하면 안 된다. Swift가 아는 것은 채널 이름과 메서드 이름뿐이다.
- **`openAppWhenRun`을 쓰지 않는다.** 명시하지 않으면 기본값 `false`로 빌드된다(실측 확인). `true`로 쓰면 설계 전체의 전제가 무너진다.
- **하드코딩 금지.** 문자열은 `lib/core/constants/strings/`의 `*Strings` 클래스, 색은 `AppColors`, 크기는 `AppSizes`.
- **기존 테스트를 삭제하지 않는다.** `.claude/hooks/protect-tests.sh`가 테스트 선언 수 감소를 차단한다.
- **한글 UI, 한글 주석.**
- **Riverpod 외의 상태 관리 라이브러리를 쓰지 않는다.**
- 새 패키지를 `pubspec.yaml`에 추가하지 않는다. 이 계획은 의존성을 늘리지 않는다.

---

### Task 1: iOS 배포 타깃을 16.0으로 올린다

App Intents는 iOS 16 이상에서만 존재한다. 이것을 먼저 하지 않으면 이후 모든 Swift 코드가 `@available` 지옥이 된다.

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET = 13.0` 3곳)
- Modify: `ios/Podfile:2` (주석 처리된 `platform :ios, '13.0'`)
- Create: `test/deploy/ios_deployment_target_test.dart`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: iOS 16.0 빌드 환경. 이후 모든 Swift 태스크가 이것에 의존한다.

- [ ] **Step 1: 실패하는 가드 테스트를 쓴다**

```dart
// test/deploy/ios_deployment_target_test.dart
//
// App Intents는 iOS 16+에서만 존재한다. 배포 타깃이 낮아지면 인텐트가
// **빌드에서 조용히 빠지고** 단축어 앱에서 앱이 사라진다 — 컴파일은 통과한다.
// 그래서 값 자체를 가드로 고정한다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pbxproj의 배포 타깃이 모두 16.0 이상이다', () {
    final src = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final matches = RegExp(
      r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);',
    ).allMatches(src).toList();

    expect(matches, isNotEmpty, reason: '배포 타깃 설정을 찾지 못했다');
    for (final m in matches) {
      final value = double.parse(m.group(1)!);
      expect(
        value,
        greaterThanOrEqualTo(16.0),
        reason: 'App Intents는 iOS 16+ 전용이다. $value로는 인텐트가 빌드에서 빠진다',
      );
    }
  });

  test('Podfile의 platform 선언이 16.0 이상이다', () {
    final src = File('ios/Podfile').readAsStringSync();
    final m = RegExp(r"^platform :ios, '([\d.]+)'", multiLine: true)
        .firstMatch(src);

    expect(m, isNotNull, reason: 'Podfile에 platform 선언이 없다(주석 해제 필요)');
    expect(double.parse(m!.group(1)!), greaterThanOrEqualTo(16.0));
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/deploy/ios_deployment_target_test.dart`
Expected: FAIL — 첫 테스트는 `13.0`이라서, 둘째는 platform 선언이 주석이라 `isNotNull`에서.

- [ ] **Step 3: 배포 타깃을 올린다**

```bash
cd /Users/kwangsukim/i_code/planroutine
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/IPHONEOS_DEPLOYMENT_TARGET = 16.0;/g' ios/Runner.xcodeproj/project.pbxproj
sed -i '' "s|^# platform :ios, '13.0'|platform :ios, '16.0'|" ios/Podfile
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `flutter test test/deploy/ios_deployment_target_test.dart`
Expected: PASS (2건)

- [ ] **Step 5: Pod을 다시 깔고 빌드가 되는지 확인한다**

Run:
```bash
cd ios && pod install && cd ..
flutter build ios --simulator --debug
```
Expected: `✓ Built build/ios/iphonesimulator/Runner.app`

빌드가 깨지면 `ios/Pods`와 `ios/Podfile.lock`을 지우고 `pod install`을 다시 한다. 이 저장소의 정상 절차이며 훅이 막지 않는다.

- [ ] **Step 6: 커밋**

```bash
git add ios/Runner.xcodeproj/project.pbxproj ios/Podfile ios/Podfile.lock test/deploy/ios_deployment_target_test.dart
git commit -m "build(ios): 배포 타깃을 16.0으로 올린다

App Intents가 iOS 16+ 전용이다. 값이 낮아지면 인텐트가 빌드에서
조용히 빠지므로 가드 테스트로 고정한다."
```

---

### Task 2: AI 등록 로직을 UI에서 떼어낸다

지금 `pasteAiSchedulesAndRegister`는 `BuildContext`와 `WidgetRef`를 요구해서 인텐트에서 부를 수 없다. **중복 체크가 그 함수 안에 인라인으로 들어 있는 것이 핵심 문제다.** 클립보드 읽기와 스낵바만 남기고 나머지를 순수한 함수로 뺀다.

**Files:**
- Create: `lib/features/import/data/ai_schedule_intake.dart`
- Modify: `lib/features/import/presentation/ai_photo_flow.dart:42-95` (추출한 함수를 부르게 바꾼다)
- Create: `test/features/import/ai_schedule_intake_test.dart`

**Interfaces:**
- Consumes: `parseAiScheduleJson(String)` → `ParsedAiSchedules(items, invalidCount)` · `registerAiSchedules(ScheduleRepository, List<AiScheduleItem>, {EntryKind kind})` → `({int created, int skipped})` · `ScheduleRepository.getSchedules()` → `Future<List<Schedule>>`
- Produces: `intakeAiScheduleText(ScheduleRepository repository, String text, {EntryKind kind})` → `Future<({int created, int dup, int invalid})>`. Task 4가 이것을 부른다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```dart
// test/features/import/ai_schedule_intake_test.dart
//
// AI 응답 텍스트를 검토 대기로 들이는 경로를 **UI 없이** 검사한다.
// 이 함수가 생긴 이유는 단축어(App Intents) 경로가 BuildContext를 가질 수
// 없기 때문이다 — 히어로와 인텐트가 **같은 함수**를 써야 중복 판정 규칙이
// 두 벌로 갈라지지 않는다.

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/import/data/ai_schedule_intake.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
  });

  tearDown(() async {
    await db.close();
  });

  const twoItems = '''
[
  {"title": "운동회", "date": "2026-10-05"},
  {"title": "학예회", "date": "2026-11-20", "description": "강당"}
]
''';

  test('정상 JSON 두 건을 검토 대기로 넣는다', () async {
    final result = await intakeAiScheduleText(repo, twoItems);

    expect(result.created, 2);
    expect(result.dup, 0);
    expect(result.invalid, 0);

    final saved = await repo.getSchedules();
    expect(saved.map((s) => s.title), containsAll(['운동회', '학예회']));
  });

  test('같은 텍스트를 두 번 넣으면 두 번째는 전부 중복이다', () async {
    await intakeAiScheduleText(repo, twoItems);
    final second = await intakeAiScheduleText(repo, twoItems);

    expect(second.created, 0);
    expect(second.dup, 2);
  });

  test('한 텍스트 안의 같은 항목도 중복으로 센다', () async {
    const dupInside = '''
[
  {"title": "운동회", "date": "2026-10-05"},
  {"title": "운동회", "date": "2026-10-05"}
]
''';
    final result = await intakeAiScheduleText(repo, dupInside);

    expect(result.created, 1);
    expect(result.dup, 1);
  });

  test('날짜 형식이 깨진 항목은 invalid로 센다', () async {
    const broken = '''
[
  {"title": "운동회", "date": "2026-10-05"},
  {"title": "형식오류", "date": "언젠가"}
]
''';
    final result = await intakeAiScheduleText(repo, broken);

    expect(result.created, 1);
    expect(result.invalid, 1);
  });

  test('JSON이 아니면 아무것도 넣지 않는다', () async {
    final result = await intakeAiScheduleText(repo, '그냥 텍스트');

    expect(result.created, 0);
    expect(result.dup, 0);
    expect(result.invalid, 0);
    expect(await repo.getSchedules(), isEmpty);
  });

  test('kind를 넘기면 그 종류로 저장한다', () async {
    await intakeAiScheduleText(repo, twoItems, kind: EntryKind.task);

    final saved = await repo.getSchedules();
    expect(saved.every((s) => s.kind == EntryKind.task), isTrue);
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/import/ai_schedule_intake_test.dart`
Expected: FAIL — `ai_schedule_intake.dart`가 없어 import 오류.

- [ ] **Step 3: 함수를 만든다**

```dart
// lib/features/import/data/ai_schedule_intake.dart
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/domain/entry_kind.dart';
import 'ai_schedule_parser.dart';
import 'ai_schedule_register.dart';

/// AI 응답 텍스트를 검토 대기로 들인다. **UI에 의존하지 않는다.**
///
/// 입력 탭 히어로(클립보드)와 단축어 인텐트(App Intents)가 **둘 다 이 함수를**
/// 쓴다. 중복 판정이 예전에는 `pasteAiSchedulesAndRegister` 안에 인라인으로
/// 있어서 두 번째 호출부가 생기는 순간 규칙이 갈라질 자리였다 — 여기로 모은다.
///
/// 반환값 셋은 성격이 다르다:
///   - [created] 실제로 들어간 건수
///   - [dup] 이미 있는 것(활성 `title + scheduled_date`)이라 건너뛴 건수.
///     같은 텍스트 안의 중복도 여기 포함한다.
///   - [invalid] 파서가 형식 오류로 버린 건수. **AI에 다시 요청해야 하는 경우**라
///     [dup]과 섞으면 사용자가 할 일을 알 수 없다.
Future<({int created, int dup, int invalid})> intakeAiScheduleText(
  ScheduleRepository repository,
  String text, {
  EntryKind kind = EntryKind.event,
}) async {
  final parsed = parseAiScheduleJson(text);
  if (parsed.items.isEmpty) {
    return (created: 0, dup: 0, invalid: parsed.invalidCount);
  }

  // 기존 활성 일정(title+date)과 대조해 중복은 넣지 않는다.
  final existing = await repository.getSchedules();
  final existingKeys = existing
      .map((s) => '${s.title}|${s.scheduledDate}')
      .toSet();
  final seen = <String>{};
  final fresh = <AiScheduleItem>[];
  var dupCount = 0;
  for (final item in parsed.items) {
    final key = '${item.title}|${item.date}';
    if (existingKeys.contains(key) || !seen.add(key)) {
      dupCount++;
    } else {
      fresh.add(item);
    }
  }

  final result = await registerAiSchedules(repository, fresh, kind: kind);

  return (
    created: result.created,
    // `insertConfirmedOrPending`이 한 번 더 걸러낸 건수(`skipped`)를 합친다.
    // 빼면 우리 키 검사를 통과한 중복이 조용히 사라진다.
    dup: dupCount + result.skipped,
    invalid: parsed.invalidCount,
  );
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `flutter test test/features/import/ai_schedule_intake_test.dart`
Expected: PASS (6건)

- [ ] **Step 5: 기존 호출부가 새 함수를 쓰게 바꾼다**

`lib/features/import/presentation/ai_photo_flow.dart`의 `pasteAiSchedulesAndRegister` 본문을 아래로 교체한다. **주석(설계 근거)은 그대로 둔다.** 바뀌는 것은 본문뿐이다.

```dart
Future<void> pasteAiSchedulesAndRegister(
  BuildContext context,
  WidgetRef ref, {
  EntryKind kind = EntryKind.event,
}) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text ?? '';
  final repository = ref.read(scheduleRepositoryProvider);
  final result = await intakeAiScheduleText(repository, text, kind: kind);
  if (!context.mounted) return;

  if (result.created == 0 && result.dup == 0) {
    // **못 뽑은 것과 못 읽은 것을 구분한다.** 형식 오류만 있었다면 AI는 답을
    // 줬는데 우리가 못 받은 것이고, 사용자가 할 일이 다르다 — 다시 복사할
    // 게 아니라 AI에 다시 요청해야 한다.
    showBulkBarSnack(
      context,
      result.invalid > 0
          ? ImportStrings.aiParseAllInvalid(result.invalid)
          : ImportStrings.aiParseEmptyFor(kind),
    );
    return;
  }

  ref.invalidate(schedulesProvider);
  showBulkBarSnack(
    context,
    ImportStrings.aiRegisterSummary(
      kind,
      created: result.created,
      dup: result.dup,
      skipped: result.invalid,
    ),
  );
}
```

import에서 더 이상 쓰지 않는 `ai_schedule_register.dart`를 빼고 `../data/ai_schedule_intake.dart`를 넣는다. `ai_schedule_parser.dart`는 `copyAiPhotoPrompt`가 `buildAiPhotoPrompt`를 쓰므로 **남긴다.**

- [ ] **Step 6: 기존 테스트가 깨지지 않았는지 확인한다**

Run: `flutter test test/features/import/ && flutter analyze`
Expected: 전부 PASS, analyze 이슈 0건

깨지는 테스트가 있으면 **테스트를 고치지 말고 구현을 고친다.** 이 태스크는 동작을 바꾸지 않는 추출이다.

- [ ] **Step 7: 커밋**

```bash
git add lib/features/import/data/ai_schedule_intake.dart lib/features/import/presentation/ai_photo_flow.dart test/features/import/ai_schedule_intake_test.dart
git commit -m "refactor(import): AI 등록 로직을 UI에서 떼어낸다

단축어 인텐트는 BuildContext를 가질 수 없다. 중복 판정이 호출부 안에
인라인으로 있으면 두 번째 경로가 생기는 순간 규칙이 두 벌로 갈라지므로
intakeAiScheduleText 하나로 모은다. 동작은 바뀌지 않는다."
```

---

### Task 3: 조회 요약을 만드는 순수 함수

인텐트가 돌려줄 텍스트를 만든다. 이 저장소의 관례대로 **순수 함수**로 두어 DB·플랫폼 없이 테스트한다(`computeNotifications`·`buildTodayView`와 같은 패턴).

**Files:**
- Create: `lib/features/calendar/domain/schedule_digest.dart`
- Create: `lib/core/constants/strings/app_intents_strings.dart`
- Modify: `lib/core/constants/app_strings.dart` (barrel export 한 줄 추가)
- Create: `test/features/calendar/schedule_digest_test.dart`

**Interfaces:**
- Consumes: `CalendarEvent`(`title`, `eventDate` String `YYYY-MM-DD`, `kind`, `completedAt`) · `EntryKind`
- Produces: `enum DigestRange { today, thisWeek, thisMonth }` (`dbValue`, `fromValue`) · `({DateTime start, DateTime end}) digestBounds(DateTime now, DigestRange range)` · `String buildScheduleDigest({required List<CalendarEvent> events, required DateTime now, required DigestRange range})`. Task 4가 셋 다 쓴다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```dart
// test/features/calendar/schedule_digest_test.dart
//
// 단축어가 돌려받는 텍스트를 만드는 순수 함수.
// DB도 플랫폼도 타지 않으므로 경계값을 직접 박아 고정한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/domain/schedule_digest.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';

CalendarEvent _event(
  String title,
  String date, {
  EntryKind kind = EntryKind.task,
  String? completedAt,
}) => CalendarEvent(
  title: title,
  eventDate: date,
  kind: kind,
  completedAt: completedAt,
);

void main() {
  // 2026-09-16은 수요일이다.
  final wednesday = DateTime(2026, 9, 16, 10, 30);

  group('digestBounds', () {
    test('오늘은 그날 하루다', () {
      final b = digestBounds(wednesday, DigestRange.today);
      expect(b.start, DateTime(2026, 9, 16));
      expect(b.end, DateTime(2026, 9, 16));
    });

    test('이번 주는 월요일부터 일요일까지다', () {
      final b = digestBounds(wednesday, DigestRange.thisWeek);
      expect(b.start, DateTime(2026, 9, 14), reason: '월요일');
      expect(b.end, DateTime(2026, 9, 20), reason: '일요일');
    });

    test('이번 달은 1일부터 말일까지다', () {
      final b = digestBounds(wednesday, DigestRange.thisMonth);
      expect(b.start, DateTime(2026, 9, 1));
      expect(b.end, DateTime(2026, 9, 30), reason: '9월은 30일까지');
    });

    test('2월 말일을 윤년까지 맞춘다', () {
      final b = digestBounds(DateTime(2028, 2, 10), DigestRange.thisMonth);
      expect(b.end, DateTime(2028, 2, 29));
    });
  });

  group('buildScheduleDigest', () {
    test('비었으면 없다고 말한다', () {
      final text = buildScheduleDigest(
        events: const [],
        now: wednesday,
        range: DigestRange.today,
      );
      expect(text, contains('없'));
    });

    test('날짜순으로 제목을 담는다', () {
      final text = buildScheduleDigest(
        events: [
          _event('학예회', '2026-09-18'),
          _event('운동회', '2026-09-16'),
        ],
        now: wednesday,
        range: DigestRange.thisWeek,
      );
      expect(text.indexOf('운동회'), lessThan(text.indexOf('학예회')));
    });

    test('완료한 항목을 표시한다', () {
      final text = buildScheduleDigest(
        events: [_event('제출', '2026-09-16', completedAt: '2026-09-16T09:00:00')],
        now: wednesday,
        range: DigestRange.today,
      );
      expect(text, contains('제출'));
      expect(text, contains('완료'));
    });

    test('업무와 행사를 종류로 구분해 적는다', () {
      final text = buildScheduleDigest(
        events: [
          _event('공문 제출', '2026-09-16'),
          _event('운동회', '2026-09-16', kind: EntryKind.event),
        ],
        now: wednesday,
        range: DigestRange.today,
      );
      expect(text, contains(EntryKind.task.label));
      expect(text, contains(EntryKind.event.label));
    });
  });

  group('DigestRange', () {
    test('모르는 값은 오늘로 폴백한다', () {
      expect(DigestRange.fromValue(null), DigestRange.today);
      expect(DigestRange.fromValue('없는값'), DigestRange.today);
    });

    test('dbValue로 되찾을 수 있다', () {
      for (final r in DigestRange.values) {
        expect(DigestRange.fromValue(r.dbValue), r);
      }
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/calendar/schedule_digest_test.dart`
Expected: FAIL — `schedule_digest.dart`가 없어 import 오류.

- [ ] **Step 3: 문자열을 만든다**

```dart
// lib/core/constants/strings/app_intents_strings.dart
/// 단축어(App Intents)가 사용자에게 돌려주는 문구.
///
/// 화면이 아니라 **단축어 결과 칸과 시리 대사**로 읽히므로 짧고 평서문이다.
abstract final class AppIntentsStrings {
  const AppIntentsStrings._();

  static const digestEmptyToday = '오늘은 등록된 일정이 없어요';
  static const digestEmptyWeek = '이번 주는 등록된 일정이 없어요';
  static const digestEmptyMonth = '이번 달은 등록된 일정이 없어요';

  static const digestHeaderToday = '오늘 일정';
  static const digestHeaderWeek = '이번 주 일정';
  static const digestHeaderMonth = '이번 달 일정';

  /// 완료한 항목 뒤에 붙는 표시.
  static const doneMark = '완료';

  /// Dart가 준비되기 전에 인텐트가 도착했을 때. **조용히 빈 결과를 주지 않는다** —
  /// 사용자가 "등록됐다"고 믿는 것이 가장 나쁜 결과다.
  static const notReady = '앱이 아직 준비되지 않았어요. 잠시 후 다시 시도해 주세요';
}
```

`lib/core/constants/app_strings.dart`의 export 목록에 알파벳 순서를 지켜 한 줄 넣는다. `export 'strings/bus_strings.dart';` **앞**이다.

```dart
export 'strings/app_intents_strings.dart';
```

- [ ] **Step 4: 순수 함수를 만든다**

```dart
// lib/features/calendar/domain/schedule_digest.dart
import '../../../core/constants/app_strings.dart';
import '../../schedule/domain/entry_kind.dart';
import 'calendar_event.dart';

/// 단축어가 물어볼 수 있는 기간.
///
/// 종류를 늘리지 않는다 — 단축어 쪽 선택지가 늘면 사용자가 고르는 비용이 커지고,
/// 임의 날짜 범위는 단축어 자체의 날짜 액션으로 조합하는 편이 낫다.
enum DigestRange {
  today('today'),
  thisWeek('this_week'),
  thisMonth('this_month');

  const DigestRange(this.dbValue);

  /// Swift가 넘기는 값. **표시 이름과 분리한다** — 문구가 바뀌어도 계약은 그대로다.
  final String dbValue;

  /// 모르는 값·null은 오늘로 폴백한다. Swift 쪽 오타가 빈 화면이 아니라
  /// 가장 흔한 질문의 답으로 떨어지게 한다.
  static DigestRange fromValue(String? value) => DigestRange.values.firstWhere(
    (r) => r.dbValue == value,
    orElse: () => DigestRange.today,
  );
}

/// 기간의 시작일과 종료일(둘 다 포함). 시각은 버린다 —
/// `getEventsByDateRange`가 `YYYY-MM-DD` 문자열로 비교하기 때문이다.
({DateTime start, DateTime end}) digestBounds(
  DateTime now,
  DigestRange range,
) {
  final today = DateTime(now.year, now.month, now.day);
  switch (range) {
    case DigestRange.today:
      return (start: today, end: today);
    case DigestRange.thisWeek:
      // ISO 기준 월요일 시작. `weekday`는 월=1, 일=7이다.
      final monday = today.subtract(Duration(days: today.weekday - 1));
      return (start: monday, end: monday.add(const Duration(days: 6)));
    case DigestRange.thisMonth:
      // 다음 달 0일 = 이번 달 말일. 윤년을 직접 계산하지 않는다.
      final last = DateTime(today.year, today.month + 1, 0);
      return (start: DateTime(today.year, today.month, 1), end: last);
  }
}

/// 일정 목록을 사람이 읽는 한 덩어리 텍스트로 만든다.
///
/// **순수 함수다** — DB도 플랫폼도 타지 않는다(`buildTodayView`와 같은 규칙).
/// 단축어는 이 문자열을 그대로 AI 앱에 넘기거나 알림으로 띄운다.
String buildScheduleDigest({
  required List<CalendarEvent> events,
  required DateTime now,
  required DigestRange range,
}) {
  if (events.isEmpty) {
    return switch (range) {
      DigestRange.today => AppIntentsStrings.digestEmptyToday,
      DigestRange.thisWeek => AppIntentsStrings.digestEmptyWeek,
      DigestRange.thisMonth => AppIntentsStrings.digestEmptyMonth,
    };
  }

  final header = switch (range) {
    DigestRange.today => AppIntentsStrings.digestHeaderToday,
    DigestRange.thisWeek => AppIntentsStrings.digestHeaderWeek,
    DigestRange.thisMonth => AppIntentsStrings.digestHeaderMonth,
  };

  // 조회 쿼리가 이미 날짜순으로 주지만, 이 함수는 순수 함수라 호출부의
  // 정렬에 기대지 않는다 — 테스트가 목록을 손으로 만들어 넘긴다.
  final sorted = [...events]
    ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

  final lines = sorted.map((e) {
    final done = e.completedAt != null ? ' (${AppIntentsStrings.doneMark})' : '';
    return '- ${e.eventDate} [${e.kind.label}] ${e.title}$done';
  });

  return '$header ${sorted.length}건\n${lines.join('\n')}';
}
```

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

Run: `flutter test test/features/calendar/schedule_digest_test.dart`
Expected: PASS (10건)

- [ ] **Step 6: 커밋**

```bash
git add lib/features/calendar/domain/schedule_digest.dart lib/core/constants/strings/app_intents_strings.dart lib/core/constants/app_strings.dart test/features/calendar/schedule_digest_test.dart
git commit -m "feat(calendar): 단축어용 일정 요약 순수 함수를 만든다

DB·플랫폼과 무관한 순수 함수로 두어 경계값(주 시작 요일, 월 말일,
윤년)을 유닛 테스트로 고정한다. computeNotifications·buildTodayView와
같은 패턴이다."
```

---

### Task 4: 채널 계약과 핸들러 (Dart)

Swift와 Dart가 공유하는 **유일한 이중화**가 채널 이름과 메서드 이름이다. 한 파일에 상수로 모으고 Task 7의 가드가 Swift 쪽과 대조한다.

**Files:**
- Create: `lib/core/app_intents/app_intents_contract.dart`
- Create: `lib/core/app_intents/app_intents_handler.dart`
- Create: `test/core/app_intents/app_intents_handler_test.dart`

**Interfaces:**
- Consumes: Task 2의 `intakeAiScheduleText` · Task 3의 `DigestRange`·`digestBounds`·`buildScheduleDigest` · `scheduleRepositoryProvider` · `calendarRepositoryProvider` · `schedulesProvider` · `ImportStrings.aiRegisterSummary`
- Produces: `AppIntentsContract`(`channelName`, `methodRegister`, `methodQuery`, `methodReady`, `argText`, `argKind`, `argRange`) · `AppIntentsHandler(ProviderContainer).handle(MethodCall)` → `Future<Object?>`. Task 5가 핸들러를 배선하고 Task 6의 Swift가 같은 이름을 쓴다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```dart
// test/core/app_intents/app_intents_handler_test.dart
//
// 단축어에서 들어오는 호출을 처리하는 핸들러.
// **핸들러는 위임만 한다** — 파싱·중복체크·요약은 각자 자기 테스트가 있고,
// 여기서 보는 것은 "인자를 옳게 풀어 넘기고 결과를 옳게 돌려주는가"다.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/app_intents/app_intents_contract.dart';
import 'package:planroutine/core/app_intents/app_intents_handler.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ProviderContainer container;
  late AppIntentsHandler handler;

  setUp(() {
    db = freshDatabaseHelper();
    container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(
          ScheduleRepository(dbHelper: db),
        ),
        calendarRepositoryProvider.overrideWithValue(
          CalendarRepository(dbHelper: db),
        ),
      ],
    );
    handler = AppIntentsHandler(container);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  const twoItems = '''
[
  {"title": "운동회", "date": "2026-10-05"},
  {"title": "학예회", "date": "2026-11-20"}
]
''';

  test('등록 호출이 건수를 담은 문구를 돌려준다', () async {
    final reply = await handler.handle(
      const MethodCall(AppIntentsContract.methodRegister, {
        AppIntentsContract.argText: twoItems,
        AppIntentsContract.argKind: 'event',
      }),
    );

    expect(reply, isA<String>());
    expect(reply as String, contains('2'));
  });

  test('등록 호출이 kind를 그대로 반영한다', () async {
    await handler.handle(
      const MethodCall(AppIntentsContract.methodRegister, {
        AppIntentsContract.argText: twoItems,
        AppIntentsContract.argKind: 'task',
      }),
    );

    final saved = await container.read(scheduleRepositoryProvider).getSchedules();
    expect(saved, isNotEmpty);
    expect(saved.every((s) => s.kind == EntryKind.task), isTrue);
  });

  test('kind가 없으면 행사로 넣는다', () async {
    await handler.handle(
      const MethodCall(AppIntentsContract.methodRegister, {
        AppIntentsContract.argText: twoItems,
      }),
    );

    final saved = await container.read(scheduleRepositoryProvider).getSchedules();
    expect(saved.every((s) => s.kind == EntryKind.event), isTrue);
  });

  test('조회 호출이 문자열을 돌려준다', () async {
    final reply = await handler.handle(
      const MethodCall(AppIntentsContract.methodQuery, {
        AppIntentsContract.argRange: 'today',
      }),
    );

    expect(reply, isA<String>());
    expect((reply as String).isNotEmpty, isTrue);
  });

  test('모르는 메서드는 MissingPluginException을 던진다', () async {
    expect(
      () => handler.handle(const MethodCall('없는메서드')),
      throwsA(isA<MissingPluginException>()),
    );
  });

  test('인자가 없어도 등록이 터지지 않는다', () async {
    final reply = await handler.handle(
      const MethodCall(AppIntentsContract.methodRegister),
    );

    expect(reply, isA<String>());
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/core/app_intents/app_intents_handler_test.dart`
Expected: FAIL — 두 파일이 없어 import 오류.

- [ ] **Step 3: 계약 상수를 만든다**

```dart
// lib/core/app_intents/app_intents_contract.dart
/// Swift(App Intents)와 Dart가 공유하는 채널 계약.
///
/// **이 저장소에서 같은 사실이 두 곳에 적히는 유일한 자리다.** Swift에는
/// Dart 상수를 import할 방법이 없어 문자열을 다시 쓸 수밖에 없다 —
/// `test/core/app_intents/app_intents_wiring_test.dart`가 두 파일을 읽어
/// 양방향으로 대조한다. 이름을 바꿀 때는 세 곳(여기·Swift·가드)이 함께 간다.
abstract final class AppIntentsContract {
  const AppIntentsContract._();

  static const channelName = 'planroutine/app_intents';

  /// Swift → Dart
  static const methodRegister = 'registerSchedules';
  static const methodQuery = 'querySchedules';

  /// Dart → Swift. 핸들러 등록이 끝났음을 알린다.
  /// **이 신호가 없으면 Swift는 인텐트를 처리하지 않고 기다린다** —
  /// 앱이 꺼진 상태에서 기동과 인텐트 실행의 순서가 보장되지 않기 때문이다.
  static const methodReady = 'ready';

  static const argText = 'text';
  static const argKind = 'kind';
  static const argRange = 'range';
}
```

- [ ] **Step 4: 핸들러를 만든다**

```dart
// lib/core/app_intents/app_intents_handler.dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/calendar/domain/schedule_digest.dart';
import '../../features/calendar/presentation/providers/calendar_providers.dart';
import '../../features/import/data/ai_schedule_intake.dart';
import '../../features/schedule/domain/entry_kind.dart';
import '../../features/schedule/presentation/providers/schedule_providers.dart';
import '../constants/app_strings.dart';
import 'app_intents_contract.dart';

/// 단축어에서 들어온 호출을 기존 Dart 경로로 넘긴다.
///
/// **여기에 업무 규칙을 쓰지 않는다.** 파싱·중복 판정은 [intakeAiScheduleText],
/// 요약은 [buildScheduleDigest]가 진다. 이 클래스가 하는 일은 인자를 풀고
/// 결과를 문자열로 돌려주는 것뿐이다 — 규칙이 여기로 새면 화면 경로와
/// 단축어 경로가 서로 다르게 동작하기 시작한다.
class AppIntentsHandler {
  const AppIntentsHandler(this._container);

  final ProviderContainer _container;

  Future<Object?> handle(MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};

    switch (call.method) {
      case AppIntentsContract.methodRegister:
        return _register(args);
      case AppIntentsContract.methodQuery:
        return _query(args);
      default:
        throw MissingPluginException(
          '알 수 없는 App Intents 메서드: ${call.method}',
        );
    }
  }

  Future<String> _register(Map<String, Object?> args) async {
    final text = args[AppIntentsContract.argText] as String? ?? '';
    // 기본값은 행사다 — 사진 AI 경로의 히어로 세그먼트와 같은 기본값이고,
    // 단축어로 넘어오는 것도 대개 AI가 일정표에서 뽑은 행사다.
    final kind = args.containsKey(AppIntentsContract.argKind)
        ? EntryKind.fromValue(args[AppIntentsContract.argKind] as String?)
        : EntryKind.event;

    final result = await intakeAiScheduleText(
      _container.read(scheduleRepositoryProvider),
      text,
      kind: kind,
    );

    // 앱이 떠 있는 상태에서 단축어를 쓰면 **같은 프로세스의 상태를 만지는 것**이라,
    // 이것을 빼면 검토 목록이 그대로여서 사용자에게는 실패로 보인다.
    _container.invalidate(schedulesProvider);

    if (result.created == 0 && result.dup == 0 && result.invalid > 0) {
      return ImportStrings.aiParseAllInvalid(result.invalid);
    }
    return ImportStrings.aiRegisterSummary(
      kind,
      created: result.created,
      dup: result.dup,
      skipped: result.invalid,
    );
  }

  Future<String> _query(Map<String, Object?> args) async {
    final range = DigestRange.fromValue(
      args[AppIntentsContract.argRange] as String?,
    );
    final now = DateTime.now();
    final bounds = digestBounds(now, range);
    final events = await _container
        .read(calendarRepositoryProvider)
        .getEventsByDateRange(bounds.start, bounds.end);

    return buildScheduleDigest(events: events, now: now, range: range);
  }
}
```

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

Run: `flutter test test/core/app_intents/app_intents_handler_test.dart`
Expected: PASS (6건)

- [ ] **Step 6: 커밋**

```bash
git add lib/core/app_intents/ test/core/app_intents/
git commit -m "feat(app-intents): 채널 계약과 핸들러를 배선한다

핸들러는 위임만 한다 — 파싱·중복 판정·요약은 각자 자기 자리에 있고
여기는 인자를 풀고 결과를 돌려주는 일만 진다. 앱이 떠 있을 때를 위해
등록 후 schedulesProvider를 invalidate한다."
```

---

### Task 5: 앱 기동에 채널을 붙이고 준비 신호를 보낸다

`main.dart`가 이미 `ProviderContainer`를 명시적으로 만들어 `UncontrolledProviderScope`로 넘기고 있다. 그 컨테이너를 그대로 핸들러에 준다.

**Files:**
- Create: `lib/core/app_intents/app_intents_bridge.dart`
- Modify: `lib/main.dart:17-18` (컨테이너 생성 직후 배선)
- Create: `test/core/app_intents/app_intents_bridge_test.dart`

**Interfaces:**
- Consumes: Task 4의 `AppIntentsContract`·`AppIntentsHandler`
- Produces: `AppIntentsBridge.attach(ProviderContainer)` → `Future<void>`. Task 6의 Swift가 `methodReady`를 받는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```dart
// test/core/app_intents/app_intents_bridge_test.dart
//
// 채널 배선과 준비 신호.
//
// ⚠️ **준비 신호가 이 기능의 급소다.** 앱이 꺼진 상태에서 단축어를 누르면
// 시스템이 앱을 백그라운드로 띄우는데, Dart `main()`과 인텐트 `perform()`의
// 도달 순서가 **보장되지 않는다**(실측에서는 Dart가 1초 빨랐지만 1회 관측이다).
// 신호가 빠지면 Swift가 영원히 기다리거나 빈 결과를 돌려준다.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/app_intents/app_intents_bridge.dart';
import 'package:planroutine/core/app_intents/app_intents_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(AppIntentsContract.channelName);

  late ProviderContainer container;
  late List<MethodCall> toSwift;

  setUp(() {
    container = ProviderContainer();
    toSwift = [];
    // Dart → Swift 방향을 가로채 `ready`가 실제로 나가는지 본다.
    messenger.setMockMethodCallHandler(channel, (call) async {
      toSwift.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    container.dispose();
  });

  test('배선하면 준비 신호를 보낸다', () async {
    await AppIntentsBridge.attach(container);

    expect(
      toSwift.map((c) => c.method),
      contains(AppIntentsContract.methodReady),
      reason: '이 신호가 없으면 Swift가 인텐트를 처리하지 못한다',
    );
  });

  test('배선 뒤에는 Swift에서 온 호출을 받는다', () async {
    await AppIntentsBridge.attach(container);

    final reply = await messenger.handlePlatformMessage(
      AppIntentsContract.channelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall(AppIntentsContract.methodQuery, {
          AppIntentsContract.argRange: 'today',
        }),
      ),
      (_) {},
    );

    expect(reply, isNotNull, reason: '핸들러가 붙지 않아 응답이 없다');
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/core/app_intents/app_intents_bridge_test.dart`
Expected: FAIL — `app_intents_bridge.dart`가 없어 import 오류.

- [ ] **Step 3: 브리지를 만든다**

```dart
// lib/core/app_intents/app_intents_bridge.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_intents_contract.dart';
import 'app_intents_handler.dart';

/// 앱 기동 시 App Intents 채널을 붙인다.
///
/// **`main()`에서 컨테이너를 만든 직후에 부른다.** 늦게 부르면 앱이 백그라운드로
/// 떠서 인텐트를 처리하려는 순간에 핸들러가 아직 없을 수 있다.
abstract final class AppIntentsBridge {
  const AppIntentsBridge._();

  static const _channel = MethodChannel(AppIntentsContract.channelName);

  /// 핸들러를 등록하고 Swift에 준비되었음을 알린다.
  ///
  /// 실패해도 앱 기동을 막지 않는다 — 단축어가 안 되는 것과 앱이 안 뜨는 것은
  /// 심각도가 다르다(`main()`의 다른 초기화와 같은 규칙).
  static Future<void> attach(ProviderContainer container) async {
    final handler = AppIntentsHandler(container);
    _channel.setMethodCallHandler(handler.handle);
    try {
      await _channel.invokeMethod(AppIntentsContract.methodReady);
    } catch (_) {
      // Swift 쪽이 없는 플랫폼(안드로이드·테스트)에서는 그냥 지나간다.
    }
  }

  /// iOS에서만 배선한다. 안드로이드에는 App Intents가 없다 —
  /// 그쪽 대응은 AppFunctions이고 이 계획의 범위 밖이다.
  ///
  /// ⚠️ `defaultTargetPlatform`이 아니라 `dart:io`를 쓴다(리포 규칙).
  /// `flutter test`에서 전자는 항상 android로 강제된다.
  static bool get isSupportedPlatform => Platform.isIOS;
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `flutter test test/core/app_intents/app_intents_bridge_test.dart`
Expected: PASS (2건)

- [ ] **Step 5: `main.dart`에 배선한다**

`lib/main.dart`의 `final container = ProviderContainer();` **바로 다음**에 넣는다. 다른 초기화(`purgeExpiredTrash` 등)보다 **먼저**다 — 그것들은 몇백 밀리초가 걸릴 수 있는데, 그 사이에 인텐트가 도착하면 핸들러가 없다.

```dart
  final container = ProviderContainer();

  // 단축어(App Intents) 채널을 **가장 먼저** 붙인다. 앱이 백그라운드로 떠서
  // 인텐트를 처리하는 경로에서는 아래 초기화들이 끝나기 전에 호출이 도착할 수 있다.
  if (AppIntentsBridge.isSupportedPlatform) {
    try {
      await AppIntentsBridge.attach(container);
    } catch (_) {}
  }
```

import를 추가한다: `import 'core/app_intents/app_intents_bridge.dart';`

- [ ] **Step 6: 전체 테스트와 정적 분석을 돌린다**

Run: `flutter test && flutter analyze`
Expected: 전부 PASS, analyze 이슈 0건

- [ ] **Step 7: 커밋**

```bash
git add lib/core/app_intents/app_intents_bridge.dart lib/main.dart test/core/app_intents/app_intents_bridge_test.dart
git commit -m "feat(app-intents): 앱 기동에 채널을 붙이고 준비 신호를 보낸다

백그라운드 기동 경로에서는 다른 초기화가 끝나기 전에 인텐트 호출이
도착할 수 있어 컨테이너 생성 직후에 배선한다. ready 신호가 없으면
Swift가 인텐트를 처리하지 못한다."
```

---

### Task 6: Swift 인텐트 둘

**Files:**
- Create: `ios/Runner/AppIntents/PlanRoutineIntents.swift`
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (새 파일 등록)

**Interfaces:**
- Consumes: Task 4의 채널 이름과 메서드 이름(문자열로 다시 쓴다) · Task 5의 `ready` 신호
- Produces: 단축어 앱에 뜨는 두 액션. Task 7의 가드가 이 파일을 읽어 검사한다.

- [ ] **Step 1: Swift 파일을 만든다**

```swift
// ios/Runner/AppIntents/PlanRoutineIntents.swift
import AppIntents
import Flutter
import UIKit

// MARK: - Dart 다리

/// Dart로 가는 통로와 준비 상태를 들고 있는 단일 창구.
///
/// **`window.rootViewController`를 쓰지 않는다** — `didFinishLaunching` 시점에
/// 아직 nil이다(실측). registrar가 주는 messenger는 그 시점에 이미 유효하다.
@available(iOS 16.0, *)
enum PlanRoutineBridge {
  /// `AppDelegate`가 채워 준다.
  static var messenger: FlutterBinaryMessenger?

  /// Dart가 핸들러 등록을 마치면 true가 된다.
  private static var isReady = false
  private static var waiters: [CheckedContinuation<Bool, Never>] = []
  private static let lock = NSLock()

  static func markReady() {
    lock.lock()
    isReady = true
    let pending = waiters
    waiters.removeAll()
    lock.unlock()
    pending.forEach { $0.resume(returning: true) }
  }

  /// Dart 준비를 기다린다. 이미 준비됐으면 즉시 통과한다.
  ///
  /// **상한은 5초다.** 실측에서 기동부터 Dart 준비까지 약 1초였고, 인텐트가
  /// 시스템에서 받는 시간이 약 30초이므로 그 안에 넉넉히 든다.
  static func waitUntilReady(timeout: TimeInterval = 5) async -> Bool {
    lock.lock()
    if isReady {
      lock.unlock()
      return true
    }
    lock.unlock()

    let waited = await withTaskGroup(of: Bool.self) { group -> Bool in
      group.addTask {
        await withCheckedContinuation { cont in
          lock.lock()
          if isReady {
            lock.unlock()
            cont.resume(returning: true)
          } else {
            waiters.append(cont)
            lock.unlock()
          }
        }
      }
      group.addTask {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        return false
      }
      let first = await group.next() ?? false
      group.cancelAll()
      return first
    }
    return waited
  }

  /// Dart를 부르고 문자열 응답을 받는다.
  @MainActor
  static func call(_ method: String, arguments: [String: Any]) async -> String? {
    guard let messenger else { return nil }
    let channel = FlutterMethodChannel(
      name: PlanRoutineChannel.name, binaryMessenger: messenger)
    return await withCheckedContinuation { cont in
      var resumed = false
      channel.invokeMethod(method, arguments: arguments) { result in
        guard !resumed else { return }
        resumed = true
        cont.resume(returning: result as? String)
      }
    }
  }
}

// MARK: - 채널 계약

/// ⚠️ **Dart의 `AppIntentsContract`와 같은 값을 다시 쓴다.**
/// Swift에서 Dart 상수를 import할 방법이 없다.
/// `test/core/app_intents/app_intents_wiring_test.dart`가 두 파일을 대조한다.
enum PlanRoutineChannel {
  static let name = "planroutine/app_intents"
  static let register = "registerSchedules"
  static let query = "querySchedules"
  static let ready = "ready"
  static let argText = "text"
  static let argKind = "kind"
  static let argRange = "range"
}

// MARK: - 종류

@available(iOS 16.0, *)
enum ScheduleKindOption: String, AppEnum {
  case event
  case task

  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "종류")
  static var caseDisplayRepresentations: [ScheduleKindOption: DisplayRepresentation] = [
    .event: "행사",
    .task: "업무",
  ]
}

@available(iOS 16.0, *)
enum RangeOption: String, AppEnum {
  case today
  case thisWeek = "this_week"
  case thisMonth = "this_month"

  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "기간")
  static var caseDisplayRepresentations: [RangeOption: DisplayRepresentation] = [
    .today: "오늘",
    .thisWeek: "이번 주",
    .thisMonth: "이번 달",
  ]
}

// MARK: - 인텐트

/// AI 앱이 뽑은 일정 텍스트를 검토 대기로 넣는다.
///
/// **`openAppWhenRun`을 쓰지 않는다** — 명시하지 않으면 기본값 `false`로 빌드돼
/// 앱이 전면에 뜨지 않는다(빌드 산출물로 확인). `true`로 바꾸면 이 기능의
/// 전제가 통째로 무너진다.
@available(iOS 16.0, *)
struct RegisterSchedulesIntent: AppIntent {
  static var title: LocalizedStringResource = "일정 등록"
  static var description = IntentDescription("AI가 뽑은 일정 텍스트를 검토 목록에 넣습니다")

  @Parameter(title: "일정 텍스트")
  var text: String

  @Parameter(title: "종류", default: .event)
  var kind: ScheduleKindOption

  static var parameterSummary: some ParameterSummary {
    Summary("\(\.$text)을(를) \(\.$kind)(으)로 등록")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard await PlanRoutineBridge.waitUntilReady() else {
      return .result(dialog: "앱이 아직 준비되지 않았어요. 잠시 후 다시 시도해 주세요")
    }
    let reply = await PlanRoutineBridge.call(
      PlanRoutineChannel.register,
      arguments: [
        PlanRoutineChannel.argText: text,
        PlanRoutineChannel.argKind: kind.rawValue,
      ]
    )
    return .result(dialog: IntentDialog(stringLiteral: reply ?? "등록하지 못했어요"))
  }
}

/// 기간을 받아 일정 목록을 텍스트로 돌려준다.
@available(iOS 16.0, *)
struct QuerySchedulesIntent: AppIntent {
  static var title: LocalizedStringResource = "일정 조회"
  static var description = IntentDescription("기간을 골라 등록된 일정을 가져옵니다")

  @Parameter(title: "기간", default: .today)
  var range: RangeOption

  static var parameterSummary: some ParameterSummary {
    Summary("\(\.$range) 일정 가져오기")
  }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard await PlanRoutineBridge.waitUntilReady() else {
      let message = "앱이 아직 준비되지 않았어요. 잠시 후 다시 시도해 주세요"
      return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
    let reply = await PlanRoutineBridge.call(
      PlanRoutineChannel.query,
      arguments: [PlanRoutineChannel.argRange: range.rawValue]
    ) ?? "일정을 가져오지 못했어요"
    return .result(value: reply, dialog: IntentDialog(stringLiteral: reply))
  }
}

@available(iOS 16.0, *)
struct PlanRoutineShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: QuerySchedulesIntent(),
      phrases: ["\(.applicationName) 일정 보기"],
      shortTitle: "일정 조회",
      systemImageName: "calendar"
    )
    AppShortcut(
      intent: RegisterSchedulesIntent(),
      phrases: ["\(.applicationName)에 일정 등록"],
      shortTitle: "일정 등록",
      systemImageName: "square.and.pencil"
    )
  }
}
```

- [ ] **Step 2: `AppDelegate`에서 messenger를 넘기고 `ready`를 받는다**

`ios/Runner/AppDelegate.swift`의 `didFinishLaunchingWithOptions`에서 `GeneratedPluginRegistrant.register(with: self)` 다음에 넣는다.

```swift
    // 단축어(App Intents)가 Dart를 부를 통로를 잡아 둔다.
    // registrar의 messenger는 이 시점에 이미 유효하다 —
    // `window?.rootViewController`는 아직 nil이라 쓸 수 없다(실측).
    if #available(iOS 16.0, *), let registrar = self.registrar(forPlugin: "PlanRoutineIntents") {
      let messenger = registrar.messenger()
      PlanRoutineBridge.messenger = messenger
      let channel = FlutterMethodChannel(
        name: PlanRoutineChannel.name, binaryMessenger: messenger)
      channel.setMethodCallHandler { call, reply in
        if call.method == PlanRoutineChannel.ready {
          PlanRoutineBridge.markReady()
          reply(nil)
        } else {
          reply(FlutterMethodNotImplemented)
        }
      }
    }
```

- [ ] **Step 3: 새 Swift 파일을 Xcode 프로젝트에 등록한다**

`flutter build`는 `project.pbxproj`에 등록되지 않은 파일을 컴파일하지 않는다. **등록하지 않으면 빌드는 통과하는데 인텐트만 없다** — 가장 헷갈리는 실패 방식이다.

Xcode를 열어 추가하는 것이 가장 안전하다.

```bash
open ios/Runner.xcworkspace
```

Xcode에서 좌측 `Runner` 그룹에 `AppIntents` 폴더를 드래그해 넣고, **Target Membership에 `Runner`가 체크되어 있는지** 확인한다.

- [ ] **Step 4: 등록되었는지 확인한다**

```bash
grep -c "PlanRoutineIntents.swift" ios/Runner.xcodeproj/project.pbxproj
```
Expected: `2` 이상 (PBXFileReference와 PBXBuildFile에 각각 한 번씩)

- [ ] **Step 5: 빌드하고 인텐트가 메타데이터에 들어갔는지 확인한다**

```bash
flutter build ios --simulator --debug
strings build/ios/iphonesimulator/Runner.app/Metadata.appintents/extract.actionsdata | grep -o '"openAppWhenRun":[a-z]*' | sort -u
strings build/ios/iphonesimulator/Runner.app/Metadata.appintents/extract.actionsdata | grep -c "RegisterSchedulesIntent"
```
Expected: `"openAppWhenRun":false`만 나오고, `RegisterSchedulesIntent`가 1건 이상.

`openAppWhenRun":true`가 하나라도 보이면 멈추고 원인을 찾는다. 앱이 전면에 뜨게 된다.

- [ ] **Step 6: 커밋**

```bash
git add ios/Runner/AppIntents/PlanRoutineIntents.swift ios/Runner/AppDelegate.swift ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat(ios): 단축어 인텐트 둘을 앱 타깃에 넣는다

패키지를 쓰지 않고 앱 타깃에 직접 둔다. openAppWhenRun을 명시하지 않아
기본값 false로 빌드되고, 앱이 백그라운드로 떠서 Dart를 부른다.
Swift는 채널 호출만 지고 업무 규칙은 갖지 않는다."
```

---

### Task 7: 가드 테스트

설계가 요구하는 가드 넷 중 **셋을 여기서** 만든다. 넷째(배포 타깃 16.0 이상)는
Task 1에서 이미 `test/deploy/ios_deployment_target_test.dart`로 만들었다. Swift는 위젯 테스트로 밟을 수 없으므로 파일을 읽어 본다 — 이 저장소가 안드로이드 알림 배선에서 이미 쓴 방법이다.

**Files:**
- Create: `test/core/app_intents/app_intents_wiring_test.dart`

**Interfaces:**
- Consumes: Task 4의 `AppIntentsContract` · Task 6의 `ios/Runner/AppIntents/PlanRoutineIntents.swift`
- Produces: 없음 (가드)

- [ ] **Step 1: 가드를 쓴다**

```dart
// test/core/app_intents/app_intents_wiring_test.dart
//
// 단축어 배선 가드.
//
// Swift는 위젯 테스트로 밟을 수 없으므로 **소스를 읽어 검사한다**
// (`android_wiring_test.dart`와 같은 방법). 실제 동작 확인은
// 시뮬레이터·실기기의 몫이고, 여기가 잡는 것은 **조용히 무너지는 전제들**이다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/app_intents/app_intents_contract.dart';

String _swift() =>
    File('ios/Runner/AppIntents/PlanRoutineIntents.swift').readAsStringSync();

String _appDelegate() =>
    File('ios/Runner/AppDelegate.swift').readAsStringSync();

void main() {
  group('채널 계약이 Swift와 Dart에서 같다', () {
    test('채널 이름과 메서드·인자 이름이 양쪽에 그대로 있다', () {
      final src = _swift();
      final shared = <String, String>{
        '채널 이름': AppIntentsContract.channelName,
        '등록 메서드': AppIntentsContract.methodRegister,
        '조회 메서드': AppIntentsContract.methodQuery,
        '준비 신호': AppIntentsContract.methodReady,
        '텍스트 인자': AppIntentsContract.argText,
        '종류 인자': AppIntentsContract.argKind,
        '기간 인자': AppIntentsContract.argRange,
      };

      for (final entry in shared.entries) {
        expect(
          src,
          contains('"${entry.value}"'),
          reason:
              '${entry.key}가 Swift에 없다. Dart에서만 바꾸면 '
              '**런타임에 조용히 무응답**이 된다',
        );
      }
    });

    test('준비 신호를 AppDelegate가 받는다', () {
      // 이것이 빠지면 Swift가 5초를 기다린 뒤 "준비되지 않았다"만 답한다.
      expect(
        _appDelegate(),
        contains('markReady'),
        reason: 'AppDelegate가 ready를 처리하지 않는다',
      );
    });
  });

  group('앱을 열지 않는다는 전제', () {
    test('openAppWhenRun을 쓰지 않는다', () {
      // 기본값이 false다. 명시하는 순간 누군가 true로 바꿀 자리가 생기고,
      // true가 되면 조회할 때마다 화면이 앱으로 전환돼 기능의 뜻이 사라진다.
      expect(
        _swift(),
        isNot(contains('openAppWhenRun')),
        reason:
            'openAppWhenRun이 등장한다. 기본값(false)에 맡기고 쓰지 않는 것이 '
            '이 기능의 전제다',
      );
    });

    test('인텐트가 앱 타깃에 있다 — 별도 확장 타깃을 만들지 않았다', () {
      // App Extension으로 옮기면 Flutter 엔진을 띄울 수 없어 Dart 호출이
      // 통째로 죽는다(flutter/flutter#152799).
      expect(
        File('ios/Runner/AppIntents/PlanRoutineIntents.swift').existsSync(),
        isTrue,
      );
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(
        pbx,
        contains('PlanRoutineIntents.swift'),
        reason: 'Xcode 프로젝트에 등록되지 않으면 빌드는 통과하는데 인텐트만 없다',
      );
    });
  });

  group('경계 — Swift에 업무 규칙을 두지 않는다', () {
    test('SQL과 테이블·컬럼 이름이 등장하지 않는다', () {
      final src = _swift();
      const forbidden = [
        'SELECT',
        'INSERT',
        'UPDATE ',
        'DELETE',
        'schedules',
        'calendar_events',
        'deleted_at',
        'scheduled_date',
      ];

      for (final word in forbidden) {
        expect(
          src,
          isNot(contains(word)),
          reason:
              '"$word"가 Swift에 있다. 스키마 지식이 두 곳으로 갈라지면 '
              'v9 마이그레이션 때 한쪽만 고쳐 조용히 어긋난다',
        );
      }
    });

    test('종류 값이 EntryKind의 DB 값과 같다', () {
      // Swift가 넘기는 rawValue가 Dart의 `EntryKind.fromValue`와 맞아야 한다.
      // 어긋나면 폴백(업무)으로 조용히 떨어져 행사가 오늘 탭에 뜬다.
      final src = _swift();
      expect(src, contains('case event'));
      expect(src, contains('case task'));
    });
  });
}
```

- [ ] **Step 2: 가드를 돌린다**

Run: `flutter test test/core/app_intents/app_intents_wiring_test.dart`
Expected: PASS (6건)

실패하면 **가드를 고치지 말고 소스를 고친다.** 가드가 잡은 것이 진짜 문제다.

- [ ] **Step 3: 가드가 실제로 잡는지 확인한다**

회귀를 일부러 심어 가드가 깨지는지 본다. 잡지 못하는 가드는 없는 것만 못하다.

```bash
# openAppWhenRun 가드가 진짜 잡는가
sed -i '' 's|  @Parameter(title: "기간", default: .today)|  static var openAppWhenRun: Bool { true }\n  @Parameter(title: "기간", default: .today)|' ios/Runner/AppIntents/PlanRoutineIntents.swift
flutter test test/core/app_intents/app_intents_wiring_test.dart  # FAIL이어야 한다
git checkout ios/Runner/AppIntents/PlanRoutineIntents.swift
flutter test test/core/app_intents/app_intents_wiring_test.dart  # 다시 PASS
```

- [ ] **Step 4: 전체 테스트를 돌린다**

Run: `flutter test && flutter analyze`
Expected: 전부 PASS, analyze 이슈 0건

- [ ] **Step 5: 커밋**

```bash
git add test/core/app_intents/app_intents_wiring_test.dart
git commit -m "test(app-intents): 배선 전제를 가드로 묶는다

채널 이름 양방향 일치, openAppWhenRun 부재, 앱 타깃 등록, Swift에
스키마 지식 부재를 검사한다. 회귀를 심어 가드가 실제로 잡는 것을 확인했다."
```

---

### Task 8: 시뮬레이터에서 실제로 태워 본다

가드가 전부 통과해도 화면은 깨질 수 있다. 이 저장소가 안드로이드 공유 기능에서 이미 겪은 일이다.

**Files:** 없음 (검증)

**Interfaces:**
- Consumes: Task 1~7 전부
- Produces: 실제 동작 증거. TestFlight 배포 판단의 근거가 된다.

- [ ] **Step 1: 빌드하고 설치한다**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
flutter build ios --simulator --debug
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

⚠️ **시뮬레이터 빌드는 ad-hoc 서명이라 App Intents가 거부한다**(`Unable to get teamId`). 개발 인증서로 다시 서명한다.

```bash
ID="Apple Development: kwang soo kim (4E83JA89WB)"
APP=build/ios/iphonesimulator/Runner.app
find "$APP/Frameworks" -maxdepth 1 -name "*.framework" -exec codesign --force --sign "$ID" --timestamp=none {} \;
codesign --force --sign "$ID" --timestamp=none "$APP"
codesign -dv "$APP" 2>&1 | grep TeamIdentifier   # not set이면 안 된다
xcrun simctl install booted "$APP"
```

- [ ] **Step 2: 앱을 한 번 켜서 색인을 만들고 끈다**

```bash
xcrun simctl launch booted com.planroutine.app
sleep 6
xcrun simctl terminate booted com.planroutine.app
```

- [ ] **Step 3: 조회를 확인한다**

시뮬레이터에서 단축어 앱을 열고, 단축어를 만들어 `일정 조회` 액션을 넣고 실행한다.

확인할 것:
- **앱이 전면에 뜨지 않는다.** 화면이 단축어 앱 그대로여야 한다.
- 결과 칸에 일정 목록 또는 "없어요" 문구가 나온다.

- [ ] **Step 4: 등록을 확인한다**

`일정 등록` 액션에 아래 텍스트를 넣고 실행한다.

```json
[{"title": "단축어 시험", "date": "2026-10-01"}]
```

확인할 것:
- 앱이 전면에 뜨지 않는다.
- `행사 1건을 검토 목록에 넣었어요` 같은 문구가 나온다.
- **앱을 켜면 입력 탭 검토 목록에 그 항목이 있다.**
- 같은 것을 한 번 더 실행하면 중복으로 잡힌다(`중복 1건 제외`).

- [ ] **Step 5: 앱이 떠 있을 때도 목록이 갱신되는지 확인한다**

앱을 입력 탭에 띄워 둔 채로 단축어를 실행하고, **앱으로 돌아왔을 때 목록에 새 항목이 있는지** 본다. 없으면 `schedulesProvider` invalidate가 동작하지 않는 것이다.

- [ ] **Step 6: 결과를 기록한다**

확인한 것과 못 한 것을 `.local/experiments/app-intent-백그라운드-flutter-엔진.md`의 변경 이력에 덧붙인다. 특히 **실기기에서 확인해야 할 것**(정식 프로비저닝에서의 서명 조건)을 남긴다.

- [ ] **Step 7: 커밋**

문서 변경이 있으면 커밋한다. 코드 변경이 없으면 이 단계는 건너뛴다.

---

## 이 계획이 다루지 않는 것

- **실기기 확인.** 시뮬레이터는 수동 `codesign`으로 서명을 맞췄다. TestFlight에 올려 정식 프로비저닝에서 다시 밟아야 한다. 배포는 `/deploy` 스킬의 몫이다.
- **안드로이드 AppFunctions.** Android 16 이상 전용이고 제미나이 연동이 비공개 미리보기다.
- **완료 체크·일괄 확정 인텐트.** 요청 범위 밖이다.
- **`AppEntity` 노출.** 조회를 인텐트로 두면 필요 없다(설계 문서의 근거 참고).
