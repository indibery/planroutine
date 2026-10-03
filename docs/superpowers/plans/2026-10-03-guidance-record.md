# 지도 기록 탭 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 선택 탭 `지도 기록`을 등록부의 두 번째 탭형 기능으로 넣는다. 학교 단계의 생활지도·교육활동 침해를 판(版)이 쌓이는 기록으로 남기고, 녹음·사진을 원본 그대로(SHA-256) 붙이며, 탭 전체를 기기 인증 잠금 안에 둔다.

**Architecture:** 새 feature `lib/features/guidance/`(domain·data·presentation). 데이터는 sqflite 새 테이블 넷(DB v10, `guidance_*`)과 앱 전용 폴더 `Application Support/guidance/`. 탭의 모든 화면은 **중첩 `ShellRoute`** 하나 아래에 있고, 그 셸의 builder가 `GuidanceLockGate`로 감싼다 — 다른 탭으로 `go`하면 셸이 dispose되어 잠금 상태가 함께 사라진다. 변경은 `GuidanceActions` 한 곳을 거쳐 `guidanceChangedProvider` 신호를 올린다.

**Tech Stack:** Flutter 3.44.8 / Dart 3.12.2, Riverpod 2.6.1, GoRouter 15, sqflite(+ffi 테스트), Freezed 3, `local_auth` 3.0.2, `record` 7.1.1, `just_audio` 0.10.6, `wakelock_plus` 1.3.3, `crypto` 3.0.7, 기존 `file_picker` 9.2.3·`permission_handler`·`path_provider`

**Spec:** `docs/superpowers/specs/2026-10-03-guidance-record-design.md`

## Global Constraints

- 기능 id `'guidance'`, 라우트 `/guidance` — **저장값이라 바꾸지 않는다.** 탭 이름 `지도 기록`.
- 테이블 `guidance_people`·`guidance_records`·`guidance_revisions`·`guidance_attachments`. DB `_databaseVersion` 9 → **10**. 마이그레이션은 `CREATE TABLE` 넷 + 인덱스 둘뿐(기존 테이블 무수정).
- 저장값: `PersonRole` `student`/`guardian`/`staff`/`other`(모르면 `other`) · `GuidanceKind` `guidance`/`infringement`(모르면 `guidance`) · `GuidanceStatus` `open`/`closed_at_school`/`transferred`(모르면 `open`) · `OccurredPrecision` `exact`/`date`/`approx` · `AttachmentType` `audio`/`image` · `AttachmentSource` `recorded`/`imported`.
- **`guidance_revisions`에는 UPDATE를 쓰지 않는다. DELETE는 `GuidanceRepository.permanentDelete` 한 곳뿐**(가드가 지킨다). 기록 시각(`guidance_records.created_at`)은 insert 뒤 바꾸지 않는다.
- 내용이 같으면(`sameContent`) 새 판을 만들지 않는다. 비교는 `normalized()`(앞뒤 공백 제거·빈 글 null) 뒤에 한다.
- 관련인에게 역할(가해·피해·목격)을 붙이지 않는다. 판에는 관련인의 **저장 시점 사본**(JSON)을 넣는다.
- 삭제는 탭 안 `삭제한 기록`으로(`guidance_records.deleted_at`). **공용 휴지통·30일 자동 정리에 넣지 않는다.** 영구 삭제 때 첨부 파일도 지운다.
- 첨부는 **변환 없이 바이트 그대로** 복사하고 SHA-256을 기록한다. 사진 고르기는 `allowCompression: false`. 첨부를 빼면 `removed_at`만 찍고 파일은 남긴다.
- 녹음: AAC `.m4a`, 모노, 64kbps, 44.1kHz. 녹음 동안 `WakelockPlus` 켬. 앱이 비활성/백그라운드가 되면(시스템 창 가드 중이 아니면) 녹음을 멈추고 그때까지 저장한다.
- 잠금: 기본 잠김, 탭 진입·백그라운드 복귀 때 자동 인증. **`SystemSheetGuard.run`으로 감싼 시스템 창(Face ID·사진/파일 선택·마이크 권한) 동안은 잠그지 않는다.** 덮개는 아래 화면을 dispose하지 않는다(`Stack` + `IgnorePointer` + `ExcludeSemantics`).
- 지도 기록 화면의 `showDialog`·`ConfirmDialog.show`·`showDatePicker`·`showTimePicker`는 **`useRootNavigator: false`** — 루트 내비게이터에 뜨면 잠금 덮개 **위**에 남는다(가드).
- Android: 이 탭이 보이는 동안 `FLAG_SECURE`. 자동 백업(클라우드)에서 `files/guidance/`만 뺀다(기기 간 이전은 포함).
- CSV 내보내기·알림·Google/기기 캘린더·오늘 탭·단축어·공용 휴지통은 `guidance`를 모른다(가드).
- Riverpod만. 문자열은 `GuidanceStrings`(새 파일), 색은 `AppColors`, 크기는 `AppSizes`. 한글 UI·주석. `!` 강제 언래핑 금지.
- 플랫폼 분기는 `dart:io`의 `Platform.isAndroid`(테스트에서는 macOS라 false).
- `ListTile` 위에 색칠된 `Container`를 끼우지 않는다. 스위치에 `activeThumbColor` 금지. 골드 채움은 `goldFill` + `onGold`.
- 위젯 테스트의 DB·파일 I/O는 `tester.runAsync()` 안에서(리포 규칙).
- **기존 테스트를 지우지 않는다**(훅이 선언 수 감소를 막는다). `lib/`·`test/` 파일을 `rm`으로 지우지 않는다(훅).
- Freezed 생성 파일은 커밋한다: `dart run build_runner build --delete-conflicting-outputs`.
- 커밋 메시지는 한국어, 끝에 두 줄:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_017CsGY18wT1wE3iKefCxJo7
  ```

## Review Focus

1. **기록을 쓰다가 사진을 고르거나 Face ID·권한 창이 뜬 사이 잠겨서 쓰던 글이 사라지는 것.** 사람은 "갔다 와도 글이 그대로"를 기대한다. → Task 5 게이트 테스트(가드 중 비활성은 무시 · 잠겨도 아래 화면의 `TextField` 글이 남는다).
2. **녹음 중 전화가 오거나 홈으로 나가는 것.** 그때까지의 녹음이 기록에 붙어 있어야 한다. → Task 8 녹음 화면 테스트(비활성 → stop → 결과 반환) + 편집 화면 테스트(결과가 첨부로 저장).
3. **v9 → v10 업그레이드 사용자.** 일정·이벤트·쪽지가 그대로이고 새 테이블이 빈 채로 생겨야 한다. → Task 2 마이그레이션 테스트.
4. **공백만 고쳐 다시 저장하는 것.** 판이 늘면 "고쳤다"는 거짓 이력이 남는다. → Task 1 `sameContent` + Task 2 `saveRevision` 테스트.
5. **명단에서 이름을 고친 뒤 옛 판을 보는 것.** 옛 판은 그때 이름 그대로여야 한다(사본). 그리고 영구 삭제·초기화 뒤 **다른 기록의 파일은 남아야** 한다. → Task 2 사본 테스트 + Task 3 파일 삭제 범위 테스트.

---

## 파일 구조

| 파일 | 역할 | Task |
|---|---|---|
| `lib/core/constants/strings/guidance_strings.dart` | 문자열 전부 | 1(이후 Task가 더함) |
| `lib/features/guidance/domain/guidance_types.dart` | enum 6개(저장값·라벨) | 1 |
| `lib/features/guidance/domain/participant.dart` | 관련인 사본 + JSON 코덱 | 1 |
| `lib/features/guidance/domain/guidance_content.dart` | 판의 내용 + `normalized()` | 1 |
| `lib/features/guidance/domain/guidance_models.dart` | `GuidanceRevision`·`GuidanceRecord`·`GuidanceAttachment`·`GuidancePerson` | 1 |
| `lib/features/guidance/domain/guidance_logic.dart` | 순수 함수(같은 내용·바뀐 칸·시각 표시·정렬·거르기·명단 붙여넣기·사람별 수) | 1 |
| `lib/core/database/database_helper.dart` | v10, 테이블 넷, 초기화 | 2 |
| `lib/features/guidance/data/guidance_repository.dart` | 기록·판·첨부 | 2 |
| `lib/features/guidance/data/guidance_people_repository.dart` | 명단 | 2 |
| `lib/features/guidance/data/guidance_file_store.dart` | 첨부 파일·SHA-256 | 3 |
| `lib/features/settings/...` | 초기화가 파일까지·확인 창 건수 | 3 |
| `android/app/src/main/res/xml/*`, `AndroidManifest.xml` | 백업 규칙 | 3 |
| `lib/features/guidance/presentation/providers/guidance_providers.dart` | 저장소·목록·필터·`GuidanceActions` | 4 |
| `lib/features/guidance/presentation/screens/guidance_list_screen.dart` | 목록(탭 첫 화면) | 4 |
| `lib/features/guidance/presentation/widgets/guidance_badges.dart` | 구분·상태 배지 | 4 |
| `lib/core/modules/*`, `lib/core/router/app_router.dart` | 등록부·중첩 셸·라우트 | 4(이후 Task가 하위 라우트 추가) |
| `lib/features/guidance/presentation/lock/*` | 잠금 게이트·인증·시스템 창 가드·FLAG_SECURE | 5 |
| `android/.../MainActivity.kt`, `styles.xml`, `ios/Runner/Info.plist` | FragmentActivity·AppCompat 테마·권한 문구 | 5, 8 |
| `lib/shared/widgets/confirm_dialog.dart` | `useRootNavigator` 인자 | 5 |
| `lib/features/guidance/presentation/screens/guidance_edit_screen.dart` | 기록 쓰기·고치기 | 6, 8 |
| `lib/features/guidance/presentation/widgets/occurred_input.dart`, `participant_picker_sheet.dart` | 사건 시각 입력·관련인 고르기 | 6 |
| `lib/features/guidance/presentation/screens/guidance_detail_screen.dart`, `guidance_history_screen.dart` | 기록 보기·수정 이력 | 7 |
| `lib/features/guidance/presentation/widgets/attachment_tile.dart`, `attachment_info_sheet.dart`, `audio_playback.dart` | 첨부 표시·재생·해시 | 7 |
| `lib/features/guidance/presentation/recording/*` | 녹음기·가져오기 래퍼·녹음 화면 | 8 |
| `lib/features/guidance/presentation/screens/guidance_people_screen.dart`, `guidance_trash_screen.dart` | 명단 관리·삭제한 기록 | 9 |
| `test/features/guidance/guidance_isolation_test.dart`, `docs/privacy_policy.md`, `CLAUDE.md`, `docs/notes/project-structure.md` | 분리 가드·방침·문서 | 10 |

---

### Task 1: 도메인 — enum · 모델 · 순수 함수 · 문자열

**Files:**
- Create: `lib/core/constants/strings/guidance_strings.dart`, `lib/features/guidance/domain/guidance_types.dart`, `lib/features/guidance/domain/participant.dart`, `lib/features/guidance/domain/guidance_content.dart`, `lib/features/guidance/domain/guidance_models.dart`, `lib/features/guidance/domain/guidance_logic.dart`
- Modify: `lib/core/constants/app_strings.dart` (barrel export 한 줄)
- Test: `test/features/guidance/domain/guidance_logic_test.dart`, `test/features/guidance/domain/guidance_models_test.dart`

**Interfaces:**
- Produces:
  - `enum PersonRole { student, guardian, staff, other }` — `String dbValue`, `String label`, `static PersonRole fromValue(String?)`
  - `enum GuidanceKind { guidance, infringement }`, `enum GuidanceStatus { open, closedAtSchool, transferred }`, `enum OccurredPrecision { exact, date, approx }`, `enum AttachmentType { audio, image }`, `enum AttachmentSource { recorded, imported }` — 모두 `dbValue`·`label`·`fromValue`
  - `Participant` (Freezed): `int? personId, required String name, @Default(PersonRole.student) PersonRole role, String? memo`; `Participant.fromMap`, `toMap()`, `static String encodeList(List<Participant>)`, `static List<Participant> decodeList(String?)`, `String get displayName`
  - `GuidanceContent` (Freezed): `kind, status, precision, DateTime? occurredAt, String? occurredText, String title, String? place, List<Participant> participants, String? facts, String? quotes, String? actions`; `GuidanceContent normalized()`
  - `GuidanceRevision` (Freezed): `int? id, required int recordId, required int revisionNo, required String savedAt, required GuidanceContent content`; `GuidanceRevision.fromMap(Map)`, `static Map<String,dynamic> contentToMap(GuidanceContent)`
  - `GuidanceRecord` (Freezed): `required int id, required String createdAt, String? deletedAt, required GuidanceRevision latest, @Default(1) int revisionCount, @Default(0) int attachmentCount`; `GuidanceContent get content`
  - `GuidanceAttachment` (Freezed): `int? id, required int recordId, required AttachmentType type, required AttachmentSource source, required String fileName, String? originalName, required String sha256, required int byteSize, int? durationMs, String? capturedAt, required String attachedAt, String? removedAt`; `fromMap`, `toMap()`, `bool get isRemoved`
  - `GuidancePerson` (Freezed): `int? id, required String name, @Default(PersonRole.student) PersonRole role, String? memo, String? archivedAt, String? createdAt, String? updatedAt`; `fromMap`, `toMap()`, `Participant toParticipant()`
  - `enum ContentField { kind, status, occurred, title, place, participants, facts, quotes, actions }` — `String label`
  - `bool sameContent(GuidanceContent a, GuidanceContent b)`
  - `Set<ContentField> changedFields(GuidanceContent before, GuidanceContent after)`
  - `String formatOccurred(GuidanceContent c, {required DateTime now})`
  - `String formatStamp(String iso, {required DateTime now})`
  - `List<GuidanceRecord> sortRecords(List<GuidanceRecord>)`
  - `bool sameParticipant(Participant a, Participant b)`
  - `List<GuidanceRecord> filterRecords(List<GuidanceRecord>, {GuidanceKind? kind, Participant? person})`
  - `List<Participant> collectParticipants(List<GuidanceRecord>)`
  - `List<String> parseRosterPaste(String raw)`
  - `Map<int, int> countRecordsByPerson(List<GuidanceRecord>)`

- [ ] **Step 1: 문자열 파일을 만든다**

`lib/core/constants/strings/guidance_strings.dart`:

```dart
/// 지도 기록(선택 탭) 문자열. 이후 Task가 이 클래스에 상수를 더한다.
class GuidanceStrings {
  GuidanceStrings._();

  // 등록부·탭
  static const title = '지도 기록';
  static const tabLabel = '지도 기록';
  static const eyebrow = 'RECORD';
  static const moduleDescription =
      '학교 단계의 생활지도·교육활동 침해를 잠금 안에 기록해 둡니다';

  // 사람 구분
  static const roleStudent = '학생';
  static const roleGuardian = '보호자';
  static const roleStaff = '교직원';
  static const roleOther = '기타';

  // 기록 구분
  static const kindGuidance = '생활지도';
  static const kindInfringement = '교육활동 침해';

  // 진행 상태
  static const statusOpen = '진행 중';
  static const statusClosedAtSchool = '학교에서 마무리';
  static const statusTransferred = '교육청 이관';
  static const statusClosedShort = '마무리';
  static const statusTransferredShort = '이관';

  // 사건 시각
  static const precisionExact = '정확히';
  static const precisionDate = '날짜만';
  static const precisionApprox = '대략';
  static const occurredUnknown = '시각 모름';

  // 첨부
  static const attachmentAudio = '녹음';
  static const attachmentImage = '사진';
  static const sourceRecorded = '앱에서 녹음';
  static const sourceImported = '가져옴';

  // 바뀐 칸 이름(수정 이력)
  static const fieldKind = '구분';
  static const fieldStatus = '진행 상태';
  static const fieldOccurred = '사건 시각';
  static const fieldTitle = '제목';
  static const fieldPlace = '장소';
  static const fieldParticipants = '관련인';
  static const fieldFacts = '경과';
  static const fieldQuotes = '들은 말';
  static const fieldActions = '판단·조치';
}
```

`lib/core/constants/app_strings.dart`의 export 목록(알파벳 순)에 한 줄 추가:

```dart
export 'strings/guidance_strings.dart';
```

- [ ] **Step 2: enum 파일을 만든다**

`lib/features/guidance/domain/guidance_types.dart`:

```dart
import '../../../core/constants/app_strings.dart';

/// 명단 사람의 구분. **역할(가해·피해·목격)이 아니다** — 사람이 누구인지만 말한다.
enum PersonRole {
  student('student', GuidanceStrings.roleStudent),
  guardian('guardian', GuidanceStrings.roleGuardian),
  staff('staff', GuidanceStrings.roleStaff),
  other('other', GuidanceStrings.roleOther);

  const PersonRole(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static PersonRole fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => other);
}

/// 기록의 종류(사람에게 붙는 것이 아니다).
enum GuidanceKind {
  guidance('guidance', GuidanceStrings.kindGuidance),
  infringement('infringement', GuidanceStrings.kindInfringement);

  const GuidanceKind(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static GuidanceKind fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => guidance);
}

enum GuidanceStatus {
  open('open', GuidanceStrings.statusOpen),
  closedAtSchool('closed_at_school', GuidanceStrings.statusClosedAtSchool),
  transferred('transferred', GuidanceStrings.statusTransferred);

  const GuidanceStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static GuidanceStatus fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => open);
}

/// 사건 시각을 얼마나 정확히 아는가. 학생 확인서도 "3월 초쯤"을 허용한다 —
/// 정확한 시각만 받으면 사용자가 지어내게 된다.
enum OccurredPrecision {
  exact('exact', GuidanceStrings.precisionExact),
  date('date', GuidanceStrings.precisionDate),
  approx('approx', GuidanceStrings.precisionApprox);

  const OccurredPrecision(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static OccurredPrecision fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => exact);
}

enum AttachmentType {
  audio('audio', GuidanceStrings.attachmentAudio),
  image('image', GuidanceStrings.attachmentImage);

  const AttachmentType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static AttachmentType fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => image);
}

enum AttachmentSource {
  recorded('recorded', GuidanceStrings.sourceRecorded),
  imported('imported', GuidanceStrings.sourceImported);

  const AttachmentSource(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static AttachmentSource fromValue(String? v) =>
      values.firstWhere((e) => e.dbValue == v, orElse: () => imported);
}
```

- [ ] **Step 3: 관련인·내용·모델 파일을 만든다**

`lib/features/guidance/domain/participant.dart`:

```dart
import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'guidance_types.dart';

part 'participant.freezed.dart';

/// 판에 들어가는 관련인 **사본**. 명단에서 이름을 고쳐도 옛 판은 이 사본을 그대로 보여 준다.
/// [personId]가 없으면 명단 밖 이름이다.
@freezed
abstract class Participant with _$Participant {
  const Participant._();

  const factory Participant({
    int? personId,
    required String name,
    @Default(PersonRole.student) PersonRole role,
    String? memo,
  }) = _Participant;

  factory Participant.fromMap(Map<String, dynamic> m) => Participant(
    personId: m['personId'] as int?,
    name: (m['name'] as String?) ?? '',
    role: PersonRole.fromValue(m['role'] as String?),
    memo: m['memo'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (personId != null) 'personId': personId,
    'name': name,
    'role': role.dbValue,
    if (memo != null) 'memo': memo,
  };

  /// `박서준 · 5반`처럼 메모를 붙인 이름. 메모가 없으면 이름만.
  String get displayName {
    final m = memo;
    return (m == null || m.isEmpty) ? name : '$name · $m';
  }

  static String encodeList(List<Participant> list) =>
      jsonEncode([for (final p in list) p.toMap()]);

  /// 깨진 값이면 빈 목록 — 판 하나가 깨졌다고 화면 전체가 죽지 않게.
  static List<Participant> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is Map<String, dynamic>) Participant.fromMap(e),
      ];
    } on FormatException {
      return const [];
    }
  }
}
```

`lib/features/guidance/domain/guidance_content.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'guidance_types.dart';
import 'participant.dart';

part 'guidance_content.freezed.dart';

/// 판 하나의 내용 — 사용자가 고칠 수 있는 칸 전부. 구분·상태·사건 시각도 여기 있어서
/// 그것을 바꾼 것도 이력에 남는다.
@freezed
abstract class GuidanceContent with _$GuidanceContent {
  const GuidanceContent._();

  const factory GuidanceContent({
    @Default(GuidanceKind.guidance) GuidanceKind kind,
    @Default(GuidanceStatus.open) GuidanceStatus status,
    @Default(OccurredPrecision.exact) OccurredPrecision precision,
    DateTime? occurredAt,
    String? occurredText,
    @Default('') String title,
    String? place,
    @Default(<Participant>[]) List<Participant> participants,
    String? facts,
    String? quotes,
    String? actions,
  }) = _GuidanceContent;

  /// 저장·비교 전에 다듬는다 — 앞뒤 공백 제거, 빈 글은 null, 정밀도에 맞지 않는 시각 정보 제거.
  /// 이것 없이 비교하면 공백 하나 고친 저장이 새 판이 된다(Review Focus 4).
  GuidanceContent normalized() {
    String? clean(String? s) {
      final t = s?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final at = occurredAt;
    return copyWith(
      title: title.trim(),
      place: clean(place),
      facts: clean(facts),
      quotes: clean(quotes),
      actions: clean(actions),
      occurredText: precision == OccurredPrecision.approx ? clean(occurredText) : null,
      occurredAt: switch (precision) {
        OccurredPrecision.exact => at == null
            ? null
            : DateTime(at.year, at.month, at.day, at.hour, at.minute),
        OccurredPrecision.date => at == null ? null : DateTime(at.year, at.month, at.day),
        OccurredPrecision.approx => null,
      },
      participants: [
        for (final p in participants)
          if (p.name.trim().isNotEmpty) p.copyWith(name: p.name.trim(), memo: clean(p.memo)),
      ],
    );
  }
}
```

`lib/features/guidance/domain/guidance_models.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/date_utils.dart';
import 'guidance_content.dart';
import 'guidance_types.dart';
import 'participant.dart';

part 'guidance_models.freezed.dart';

/// 판 한 줄(`guidance_revisions`). **추가만 한다** — 고치거나 지우지 않는다.
@freezed
abstract class GuidanceRevision with _$GuidanceRevision {
  const GuidanceRevision._();

  const factory GuidanceRevision({
    int? id,
    required int recordId,
    required int revisionNo,
    required String savedAt,
    required GuidanceContent content,
  }) = _GuidanceRevision;

  factory GuidanceRevision.fromMap(Map<String, dynamic> m) {
    final at = m['occurred_at'] as String?;
    return GuidanceRevision(
      id: m['id'] as int?,
      recordId: m['record_id'] as int,
      revisionNo: m['revision_no'] as int,
      savedAt: m['saved_at'] as String,
      content: GuidanceContent(
        kind: GuidanceKind.fromValue(m['kind'] as String?),
        status: GuidanceStatus.fromValue(m['status'] as String?),
        precision: OccurredPrecision.fromValue(m['occurred_precision'] as String?),
        occurredAt: at == null ? null : DateTime.tryParse(at),
        occurredText: m['occurred_text'] as String?,
        title: (m['title'] as String?) ?? '',
        place: m['place'] as String?,
        participants: Participant.decodeList(m['participants'] as String?),
        facts: m['facts'] as String?,
        quotes: m['quotes'] as String?,
        actions: m['actions'] as String?,
      ),
    );
  }

  /// 판의 내용 칸만 맵으로. `record_id`·`revision_no`·`saved_at`은 저장소가 붙인다.
  static Map<String, dynamic> contentToMap(GuidanceContent c) {
    final n = c.normalized();
    final at = n.occurredAt;
    return {
      'kind': n.kind.dbValue,
      'status': n.status.dbValue,
      'occurred_precision': n.precision.dbValue,
      'occurred_at': at == null
          ? null
          : n.precision == OccurredPrecision.date
              ? formatDate(at)
              : at.toIso8601String(),
      'occurred_text': n.occurredText,
      'title': n.title,
      'place': n.place,
      'participants': Participant.encodeList(n.participants),
      'facts': n.facts,
      'quotes': n.quotes,
      'actions': n.actions,
    };
  }
}

/// 목록·보기용 — 기록 몸통 + 최신 판 + 개수.
@freezed
abstract class GuidanceRecord with _$GuidanceRecord {
  const GuidanceRecord._();

  const factory GuidanceRecord({
    required int id,
    required String createdAt,
    String? deletedAt,
    required GuidanceRevision latest,
    @Default(1) int revisionCount,
    @Default(0) int attachmentCount,
  }) = _GuidanceRecord;

  GuidanceContent get content => latest.content;
}

@freezed
abstract class GuidanceAttachment with _$GuidanceAttachment {
  const GuidanceAttachment._();

  const factory GuidanceAttachment({
    int? id,
    required int recordId,
    required AttachmentType type,
    required AttachmentSource source,
    required String fileName,
    String? originalName,
    required String sha256,
    required int byteSize,
    int? durationMs,
    String? capturedAt,
    required String attachedAt,
    String? removedAt,
  }) = _GuidanceAttachment;

  factory GuidanceAttachment.fromMap(Map<String, dynamic> m) => GuidanceAttachment(
    id: m['id'] as int?,
    recordId: m['record_id'] as int,
    type: AttachmentType.fromValue(m['type'] as String?),
    source: AttachmentSource.fromValue(m['source'] as String?),
    fileName: m['file_name'] as String,
    originalName: m['original_name'] as String?,
    sha256: m['sha256'] as String,
    byteSize: m['byte_size'] as int,
    durationMs: m['duration_ms'] as int?,
    capturedAt: m['captured_at'] as String?,
    attachedAt: m['attached_at'] as String,
    removedAt: m['removed_at'] as String?,
  );

  /// `removed_at`은 넣지 않는다 — 빼기는 전용 메서드만 만진다.
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'record_id': recordId,
    'type': type.dbValue,
    'source': source.dbValue,
    'file_name': fileName,
    'original_name': originalName,
    'sha256': sha256,
    'byte_size': byteSize,
    'duration_ms': durationMs,
    'captured_at': capturedAt,
    'attached_at': attachedAt,
  };

  bool get isRemoved => removedAt != null;
}

@freezed
abstract class GuidancePerson with _$GuidancePerson {
  const GuidancePerson._();

  const factory GuidancePerson({
    int? id,
    required String name,
    @Default(PersonRole.student) PersonRole role,
    String? memo,
    String? archivedAt,
    String? createdAt,
    String? updatedAt,
  }) = _GuidancePerson;

  factory GuidancePerson.fromMap(Map<String, dynamic> m) => GuidancePerson(
    id: m['id'] as int?,
    name: m['name'] as String,
    role: PersonRole.fromValue(m['role'] as String?),
    memo: m['memo'] as String?,
    archivedAt: m['archived_at'] as String?,
    createdAt: m['created_at'] as String?,
    updatedAt: m['updated_at'] as String?,
  );

  /// `archived_at`은 넣지 않는다 — 보관은 전용 메서드만 만진다.
  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      if (id != null) 'id': id,
      'name': name,
      'role': role.dbValue,
      'memo': memo,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
    };
  }

  Participant toParticipant() =>
      Participant(personId: id, name: name, role: role, memo: memo);
}
```

- [ ] **Step 4: 생성 파일을 만들고 컴파일을 확인한다**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `participant.freezed.dart`, `guidance_content.freezed.dart`, `guidance_models.freezed.dart` 생성, 오류 없음.

- [ ] **Step 5: 순수 함수 실패 테스트를 쓴다**

`test/features/guidance/domain/guidance_logic_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_logic.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';

GuidanceRecord _rec(
  int id, {
  DateTime? at,
  OccurredPrecision precision = OccurredPrecision.exact,
  String createdAt = '2026-10-01T09:00:00.000',
  GuidanceKind kind = GuidanceKind.guidance,
  List<Participant> people = const [],
}) => GuidanceRecord(
  id: id,
  createdAt: createdAt,
  latest: GuidanceRevision(
    recordId: id,
    revisionNo: 1,
    savedAt: createdAt,
    content: GuidanceContent(
      title: '기록 $id',
      kind: kind,
      precision: precision,
      occurredAt: at,
      participants: people,
    ),
  ),
);

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  final now = DateTime(2026, 10, 3, 12);

  group('sameContent', () {
    test('앞뒤 공백·빈 글만 다르면 같은 내용이다', () {
      const a = GuidanceContent(title: '복도 다툼', facts: '밀침', place: '');
      const b = GuidanceContent(title: ' 복도 다툼 ', facts: '밀침\n', place: null);
      expect(sameContent(a, b), isTrue);
    });

    test('글 하나가 바뀌면 다른 내용이다', () {
      const a = GuidanceContent(title: '복도 다툼', facts: '밀침');
      const b = GuidanceContent(title: '복도 다툼', facts: '밀침. 보건실 확인');
      expect(sameContent(a, b), isFalse);
    });

    test('날짜만이면 시각 차이는 무시한다', () {
      final a = GuidanceContent(
        title: 't',
        precision: OccurredPrecision.date,
        occurredAt: DateTime(2026, 10, 2, 9),
      );
      final b = a.copyWith(occurredAt: DateTime(2026, 10, 2, 18));
      expect(sameContent(a, b), isTrue);
    });
  });

  test('changedFields는 바뀐 칸만 돌려준다', () {
    const a = GuidanceContent(title: 't', facts: '가');
    final b = a.copyWith(facts: '나', status: GuidanceStatus.transferred);
    expect(changedFields(a, b), {ContentField.facts, ContentField.status});
  });

  group('formatOccurred', () {
    test('정확히 — 월.일 (요일) 시:분', () {
      final c = GuidanceContent(title: 't', occurredAt: DateTime(2026, 10, 2, 15, 30));
      expect(formatOccurred(c, now: now), '10.2 (금) 15:30');
    });

    test('날짜만 — 시각 없이', () {
      final c = GuidanceContent(
        title: 't',
        precision: OccurredPrecision.date,
        occurredAt: DateTime(2026, 10, 2),
      );
      expect(formatOccurred(c, now: now), '10.2 (금)');
    });

    test('다른 해면 연도를 붙인다', () {
      final c = GuidanceContent(title: 't', occurredAt: DateTime(2025, 3, 4, 9, 5));
      expect(formatOccurred(c, now: now), '2025.3.4 (화) 09:05');
    });

    test('대략 — 적은 글 그대로, 없으면 시각 모름', () {
      const c = GuidanceContent(
        title: 't',
        precision: OccurredPrecision.approx,
        occurredText: '3월 초~여름방학 전',
      );
      expect(formatOccurred(c, now: now), '3월 초~여름방학 전');
      expect(
        formatOccurred(c.copyWith(occurredText: null), now: now),
        '시각 모름',
      );
    });
  });

  test('sortRecords — 사건 시각이 최근인 것이 위, 대략은 기록 시각으로', () {
    final sorted = sortRecords([
      _rec(1, at: DateTime(2026, 9, 25)),
      _rec(2, precision: OccurredPrecision.approx, createdAt: '2026-10-02T08:00:00.000'),
      _rec(3, at: DateTime(2026, 9, 30)),
    ]);
    expect(sorted.map((r) => r.id), [2, 3, 1]);
  });

  group('filterRecords', () {
    const kim = Participant(personId: 7, name: '김하늘');
    const park = Participant(name: '박서준', memo: '5반');
    final records = [
      _rec(1, people: [kim]),
      _rec(2, people: [park], kind: GuidanceKind.infringement),
      _rec(3, people: [kim, park]),
    ];

    test('명단 사람은 id로 찾는다(이름이 바뀌어도)', () {
      final got = filterRecords(
        records,
        person: const Participant(personId: 7, name: '김하늘(개명)'),
      );
      expect(got.map((r) => r.id), [1, 3]);
    });

    test('명단 밖 사람은 이름으로 찾는다', () {
      final got = filterRecords(records, person: const Participant(name: '박서준'));
      expect(got.map((r) => r.id), [2, 3]);
    });

    test('구분으로 거른다', () {
      final got = filterRecords(records, kind: GuidanceKind.infringement);
      expect(got.map((r) => r.id), [2]);
    });
  });

  test('collectParticipants — 겹치지 않게 모은다', () {
    const kim = Participant(personId: 7, name: '김하늘');
    final got = collectParticipants([
      _rec(1, people: [kim]),
      _rec(2, people: [kim, const Participant(name: '박서준')]),
    ]);
    expect(got.map((p) => p.name), ['김하늘', '박서준']);
  });

  test('parseRosterPaste — 번호·빈 줄·중복을 걷어낸다', () {
    const raw = '1. 김하늘\n2\t이도윤\n\n  최민서  \n김하늘\n10) 박서준';
    expect(parseRosterPaste(raw), ['김하늘', '이도윤', '최민서', '박서준']);
  });

  test('countRecordsByPerson — 명단 사람만 센다', () {
    const kim = Participant(personId: 7, name: '김하늘');
    final got = countRecordsByPerson([
      _rec(1, people: [kim]),
      _rec(2, people: [kim, const Participant(name: '박서준')]),
    ]);
    expect(got, {7: 2});
  });
}
```

`test/features/guidance/domain/guidance_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';

void main() {
  test('모르는 저장값은 안전한 기본값으로 떨어진다', () {
    expect(PersonRole.fromValue('teacher'), PersonRole.other);
    expect(GuidanceKind.fromValue(null), GuidanceKind.guidance);
    expect(GuidanceStatus.fromValue('x'), GuidanceStatus.open);
  });

  test('관련인 목록은 JSON으로 왕복한다', () {
    const list = [
      Participant(personId: 3, name: '김하늘'),
      Participant(name: '박서준', role: PersonRole.student, memo: '5반'),
    ];
    expect(Participant.decodeList(Participant.encodeList(list)), list);
  });

  test('깨진 관련인 JSON은 빈 목록이다', () {
    expect(Participant.decodeList('{oops'), isEmpty);
    expect(Participant.decodeList(null), isEmpty);
  });

  test('판 내용은 맵으로 왕복한다', () {
    final content = GuidanceContent(
      kind: GuidanceKind.infringement,
      status: GuidanceStatus.transferred,
      occurredAt: DateTime(2026, 10, 2, 15, 30),
      title: '학부모 전화',
      participants: const [Participant(name: '보호자', role: PersonRole.guardian)],
      quotes: '"가만두지 않겠다"',
      actions: '교감 보고 10.2 16:00',
    );
    final map = {
      'id': 1,
      'record_id': 9,
      'revision_no': 2,
      'saved_at': '2026-10-02T17:00:00.000',
      ...GuidanceRevision.contentToMap(content),
    };
    final back = GuidanceRevision.fromMap(map);
    expect(back.content, content.normalized());
    expect(back.revisionNo, 2);
  });

  test('날짜만인 사건 시각은 yyyy-MM-dd로 저장한다', () {
    final map = GuidanceRevision.contentToMap(
      GuidanceContent(
        title: 't',
        precision: OccurredPrecision.date,
        occurredAt: DateTime(2026, 10, 2, 15),
      ),
    );
    expect(map['occurred_at'], '2026-10-02');
  });
}
```

- [ ] **Step 6: 실패를 확인한다**

Run: `flutter test test/features/guidance/domain/`
Expected: FAIL — `guidance_logic.dart`가 없다는 컴파일 오류.

- [ ] **Step 7: 순수 함수를 구현한다**

`lib/features/guidance/domain/guidance_logic.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import 'guidance_content.dart';
import 'guidance_models.dart';
import 'guidance_types.dart';
import 'participant.dart';

/// 수정 이력에서 "무엇이 바뀌었나"를 말할 때 쓰는 칸 이름.
enum ContentField {
  kind(GuidanceStrings.fieldKind),
  status(GuidanceStrings.fieldStatus),
  occurred(GuidanceStrings.fieldOccurred),
  title(GuidanceStrings.fieldTitle),
  place(GuidanceStrings.fieldPlace),
  participants(GuidanceStrings.fieldParticipants),
  facts(GuidanceStrings.fieldFacts),
  quotes(GuidanceStrings.fieldQuotes),
  actions(GuidanceStrings.fieldActions);

  const ContentField(this.label);
  final String label;
}

/// 다듬은 뒤 같으면 같은 내용이다 — 이때는 새 판을 만들지 않는다.
bool sameContent(GuidanceContent a, GuidanceContent b) =>
    a.normalized() == b.normalized();

Set<ContentField> changedFields(GuidanceContent before, GuidanceContent after) {
  final a = before.normalized();
  final b = after.normalized();
  return {
    if (a.kind != b.kind) ContentField.kind,
    if (a.status != b.status) ContentField.status,
    if (a.precision != b.precision ||
        a.occurredAt != b.occurredAt ||
        a.occurredText != b.occurredText)
      ContentField.occurred,
    if (a.title != b.title) ContentField.title,
    if (a.place != b.place) ContentField.place,
    if (!listEquals(a.participants, b.participants)) ContentField.participants,
    if (a.facts != b.facts) ContentField.facts,
    if (a.quotes != b.quotes) ContentField.quotes,
    if (a.actions != b.actions) ContentField.actions,
  };
}

String _day(DateTime d, DateTime now) {
  final head = d.year == now.year ? '${d.month}.${d.day}' : '${d.year}.${d.month}.${d.day}';
  return '$head (${DateFormat.E('ko').format(d)})';
}

String _time(DateTime d) => DateFormat('HH:mm').format(d);

/// 사건 시각 한 줄. 올해가 아니면 연도를 붙인다.
String formatOccurred(GuidanceContent c, {required DateTime now}) {
  final at = c.occurredAt;
  return switch (c.precision) {
    OccurredPrecision.approx => c.occurredText ?? GuidanceStrings.occurredUnknown,
    OccurredPrecision.date =>
      at == null ? GuidanceStrings.occurredUnknown : _day(at, now),
    OccurredPrecision.exact =>
      at == null ? GuidanceStrings.occurredUnknown : '${_day(at, now)} ${_time(at)}',
  };
}

/// 기록 시각·저장 시각처럼 ISO 문자열로 저장된 시각 한 줄.
String formatStamp(String iso, {required DateTime now}) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_day(d, now)} ${_time(d)}';
}

DateTime _sortKey(GuidanceRecord r) =>
    r.content.occurredAt ?? DateTime.tryParse(r.createdAt) ?? DateTime(1970);

/// 사건 시각이 최근인 것이 위. 사건 시각이 없으면(대략) 기록 시각으로.
List<GuidanceRecord> sortRecords(List<GuidanceRecord> records) {
  final list = [...records];
  list.sort((a, b) {
    final byTime = _sortKey(b).compareTo(_sortKey(a));
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });
  return list;
}

/// 명단 사람은 id로, 명단 밖 사람은 이름으로 같은 사람을 판정한다.
bool sameParticipant(Participant a, Participant b) {
  final ai = a.personId;
  final bi = b.personId;
  if (ai != null || bi != null) return ai == bi;
  return a.name == b.name;
}

List<GuidanceRecord> filterRecords(
  List<GuidanceRecord> records, {
  GuidanceKind? kind,
  Participant? person,
}) => [
  for (final r in records)
    if ((kind == null || r.content.kind == kind) &&
        (person == null || r.content.participants.any((p) => sameParticipant(p, person))))
      r,
];

/// 목록의 `사람` 고르기에 쓸 후보 — 기록에 등장한 사람(명단 밖 포함), 처음 등장 순.
List<Participant> collectParticipants(List<GuidanceRecord> records) {
  final out = <Participant>[];
  for (final r in records) {
    for (final p in r.content.participants) {
      if (!out.any((q) => sameParticipant(q, p))) out.add(p);
    }
  }
  return out;
}

final _leadingNumber = RegExp(r'^\d+\s*[.)\t]?\s*');

/// 명단 붙여넣기 — 줄마다 한 명. 앞의 번호(`1.`·`2\t`·`10)`)·빈 줄·중복을 걷어낸다.
List<String> parseRosterPaste(String raw) {
  final out = <String>[];
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final name = line.trim().replaceFirst(_leadingNumber, '').trim();
    if (name.isNotEmpty && !out.contains(name)) out.add(name);
  }
  return out;
}

/// 명단 관리 화면의 `기록 N` — 명단 사람(personId 있음)만 센다.
Map<int, int> countRecordsByPerson(List<GuidanceRecord> records) {
  final counts = <int, int>{};
  for (final r in records) {
    final ids = {for (final p in r.content.participants) ?p.personId};
    for (final id in ids) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return counts;
}
```

- [ ] **Step 8: 통과를 확인한다**

Run: `flutter test test/features/guidance/domain/ && flutter analyze lib/features/guidance lib/core/constants`
Expected: 전부 PASS, analyze `No issues found!`

- [ ] **Step 9: 커밋**

```bash
git add lib/core/constants/strings/guidance_strings.dart lib/core/constants/app_strings.dart lib/features/guidance/domain test/features/guidance/domain
git commit -m "feat(guidance): 지도 기록 도메인 — 판 내용·관련인 사본·순수 함수

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017CsGY18wT1wE3iKefCxJo7"
```

---

### Task 2: DB v10 · 기록 저장소 · 명단 저장소

**Files:**
- Modify: `lib/core/database/database_helper.dart` (`_databaseVersion` 10, 테이블 상수 넷, `_onUpgrade` 끝에 `oldVersion < 10`, `_onCreate` 끝, `_createGuidance`, `resetAllData`, 클래스 주석의 마이그레이션 목록)
- Create: `lib/features/guidance/data/guidance_repository.dart`, `lib/features/guidance/data/guidance_people_repository.dart`
- Test: `test/features/guidance/data/guidance_repository_test.dart`, `test/features/guidance/data/guidance_people_repository_test.dart`, `test/features/guidance/data/guidance_append_only_guard_test.dart`, `test/core/database/guidance_migration_test.dart`

**Interfaces:**
- Consumes: Task 1의 모델 전부.
- Produces:
  - `DatabaseHelper.tableGuidancePeople = 'guidance_people'`, `tableGuidanceRecords = 'guidance_records'`, `tableGuidanceRevisions = 'guidance_revisions'`, `tableGuidanceAttachments = 'guidance_attachments'`
  - `GuidanceRepository({DatabaseHelper? dbHelper})`:
    - `Future<int> create(GuidanceContent content)` — 기록 + 판 1, 기록 id 반환
    - `Future<bool> saveRevision(int recordId, GuidanceContent content)` — 같은 내용이면 false
    - `Future<List<GuidanceRecord>> getActive()`, `Future<List<GuidanceRecord>> getDeleted()`, `Future<GuidanceRecord?> getRecord(int id)`
    - `Future<List<GuidanceRevision>> getRevisions(int recordId)` — 최신 판이 앞
    - `Future<void> softDelete(int id)`, `Future<void> restore(int id)`
    - `Future<List<String>> permanentDelete(int id)` — 지운 첨부의 `file_name` 목록 반환
    - `Future<GuidanceAttachment> addAttachment(GuidanceAttachment a)`, `Future<void> removeAttachment(int attachmentId)`, `Future<List<GuidanceAttachment>> getAttachments(int recordId)` — 뺀 것 포함, 붙인 순
    - `Future<({int records, int attachments})> counts()` — 삭제한 기록·뺀 첨부 포함 전부
  - `GuidancePeopleRepository({DatabaseHelper? dbHelper})`:
    - `Future<GuidancePerson> add(GuidancePerson p)`, `Future<int> addNames(List<String> names, {PersonRole role = PersonRole.student})` — 추가한 수
    - `Future<void> update(GuidancePerson p)`, `Future<void> archive(int id)`, `Future<void> unarchive(int id)`
    - `Future<List<GuidancePerson>> getActive()`, `Future<List<GuidancePerson>> getArchived()`

- [ ] **Step 1: 마이그레이션 실패 테스트를 쓴다**

`test/core/database/guidance_migration_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  test('v9 → v10: 기존 데이터는 그대로, 지도 기록 테이블 넷이 빈 채로 생긴다', () async {
    final dir = await Directory.systemTemp.createTemp('guidance_mig');
    final path = '${dir.path}/v9.db';
    // v9 스키마를 흉내 낸다 — 이번 마이그레이션에 필요한 것은 기존 테이블이 남는지뿐이다.
    final v9 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE memos (id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, '
            "color TEXT NOT NULL DEFAULT 'yellow', memo_date TEXT, sort_order INTEGER NOT NULL DEFAULT 0, "
            'created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)',
          );
          await db.insert('memos', {
            'text': '남아야 할 쪽지',
            'created_at': '2026-10-01T00:00:00.000',
            'updated_at': '2026-10-01T00:00:00.000',
          });
        },
      ),
    );
    await v9.close();

    final helper = DatabaseHelper.forTesting(path: path);
    final db = await helper.database;
    expect(await db.getVersion(), 10);
    expect((await db.query('memos')).single['text'], '남아야 할 쪽지');
    for (final t in [
      DatabaseHelper.tableGuidancePeople,
      DatabaseHelper.tableGuidanceRecords,
      DatabaseHelper.tableGuidanceRevisions,
      DatabaseHelper.tableGuidanceAttachments,
    ]) {
      expect(await db.query(t), isEmpty, reason: t);
    }
    await helper.close();
    await dir.delete(recursive: true);
  });
}
```


- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/core/database/guidance_migration_test.dart`
Expected: FAIL — `tableGuidancePeople` 미정의.

- [ ] **Step 3: DatabaseHelper를 고친다**

`lib/core/database/database_helper.dart`:

```dart
  static const _databaseVersion = 10;

  // 테이블명
  static const tableImportedSchedules = 'imported_schedules';
  static const tableSchedules = 'schedules';
  static const tableCalendarEvents = 'calendar_events';
  static const tableMemos = 'memos';
  static const tableGuidancePeople = 'guidance_people';
  static const tableGuidanceRecords = 'guidance_records';
  static const tableGuidanceRevisions = 'guidance_revisions';
  static const tableGuidanceAttachments = 'guidance_attachments';
```

클래스 주석의 마이그레이션 목록 끝에 한 줄:

```dart
  /// v9 → v10: 지도 기록. [guidance_*] 테이블 넷 신설(기존 테이블은 그대로).
```

`_onUpgrade`의 `if (oldVersion < 9) {...}` 뒤:

```dart
    if (oldVersion < 10) {
      // 지도 기록(선택 탭). 기존 테이블은 건드리지 않는다.
      await _createGuidance(db);
    }
```

`_onCreate` 끝의 `await _createMemos(db);` 뒤에 `await _createGuidance(db);`. 그리고 `_createMemos` 아래에:

```dart
  /// 지도 기록 테이블 넷. `_onCreate`와 v9→v10 업그레이드가 같은 정의를 쓴다.
  ///
  /// `guidance_revisions`는 **추가만 한다** — UPDATE 없음, DELETE는 영구 삭제 한 곳
  /// (`guidance_append_only_guard_test.dart`가 지킨다).
  static Future<void> _createGuidance(Database db) async {
    await db.execute('''
      CREATE TABLE $tableGuidancePeople (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'student',
        memo TEXT,
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableGuidanceRecords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableGuidanceRevisions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL,
        revision_no INTEGER NOT NULL,
        saved_at TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'guidance',
        status TEXT NOT NULL DEFAULT 'open',
        occurred_precision TEXT NOT NULL DEFAULT 'exact',
        occurred_at TEXT,
        occurred_text TEXT,
        title TEXT NOT NULL,
        place TEXT,
        participants TEXT NOT NULL DEFAULT '[]',
        facts TEXT,
        quotes TEXT,
        actions TEXT,
        UNIQUE (record_id, revision_no),
        FOREIGN KEY (record_id) REFERENCES $tableGuidanceRecords(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableGuidanceAttachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        source TEXT NOT NULL,
        file_name TEXT NOT NULL,
        original_name TEXT,
        sha256 TEXT NOT NULL,
        byte_size INTEGER NOT NULL,
        duration_ms INTEGER,
        captured_at TEXT,
        attached_at TEXT NOT NULL,
        removed_at TEXT,
        FOREIGN KEY (record_id) REFERENCES $tableGuidanceRecords(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_guidance_rev_record ON $tableGuidanceRevisions(record_id)',
    );
    await db.execute(
      'CREATE INDEX idx_guidance_att_record ON $tableGuidanceAttachments(record_id)',
    );
  }
```

`resetAllData`의 트랜잭션에서 `await txn.delete(tableMemos);` 뒤(자식 → 부모 순):

```dart
      await txn.delete(tableGuidanceAttachments);
      await txn.delete(tableGuidanceRevisions);
      await txn.delete(tableGuidanceRecords);
      await txn.delete(tableGuidancePeople);
```

- [ ] **Step 4: 마이그레이션 테스트 통과를 확인한다**

Run: `flutter test test/core/database/`
Expected: PASS(기존 `database_helper_test.dart` 포함).

- [ ] **Step 5: 저장소 실패 테스트를 쓴다**

`test/features/guidance/data/guidance_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';

import '../../../helpers/test_database.dart';

GuidanceAttachment _att(int recordId, String name) => GuidanceAttachment(
  recordId: recordId,
  type: AttachmentType.audio,
  source: AttachmentSource.recorded,
  fileName: name,
  sha256: 'abc',
  byteSize: 3,
  attachedAt: DateTime.now().toIso8601String(),
);

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  test('새 기록은 판 1이고 목록에 뜬다', () async {
    final id = await repo.create(const GuidanceContent(title: '복도 다툼'));
    final list = await repo.getActive();
    expect(list.single.id, id);
    expect(list.single.latest.revisionNo, 1);
    expect(list.single.revisionCount, 1);
    expect(list.single.content.title, '복도 다툼');
  });

  test('저장할 때마다 판이 늘고 이전 판은 그대로 남는다', () async {
    final id = await repo.create(const GuidanceContent(title: 't', facts: '처음'));
    expect(await repo.saveRevision(id, const GuidanceContent(title: 't', facts: '고침')), isTrue);
    final revs = await repo.getRevisions(id);
    expect(revs.map((r) => r.revisionNo), [2, 1]);
    expect(revs.last.content.facts, '처음');
    expect((await repo.getRecord(id))?.revisionCount, 2);
  });

  test('같은 내용(공백만 다름)이면 판을 만들지 않는다', () async {
    final id = await repo.create(const GuidanceContent(title: 't', facts: '가'));
    expect(await repo.saveRevision(id, const GuidanceContent(title: ' t ', facts: '가\n')), isFalse);
    expect(await repo.getRevisions(id), hasLength(1));
  });

  test('기록 시각은 판을 더해도 바뀌지 않는다', () async {
    final id = await repo.create(const GuidanceContent(title: 't'));
    final before = (await repo.getRecord(id))?.createdAt;
    await repo.saveRevision(id, const GuidanceContent(title: 't2'));
    expect((await repo.getRecord(id))?.createdAt, before);
  });

  test('관련인은 사본이라 옛 판의 이름은 그대로다', () async {
    final id = await repo.create(
      const GuidanceContent(title: 't', participants: [Participant(personId: 1, name: '김하늘')]),
    );
    await repo.saveRevision(
      id,
      const GuidanceContent(title: 't', participants: [Participant(personId: 1, name: '김하늘(바뀜)')]),
    );
    final revs = await repo.getRevisions(id);
    expect(revs.last.content.participants.single.name, '김하늘');
  });

  test('삭제하면 삭제한 기록으로 가고, 되살리면 돌아온다', () async {
    final id = await repo.create(const GuidanceContent(title: 't'));
    await repo.softDelete(id);
    expect(await repo.getActive(), isEmpty);
    expect((await repo.getDeleted()).single.id, id);
    await repo.restore(id);
    expect((await repo.getActive()).single.id, id);
  });

  test('첨부는 붙이고 빼도 행이 남는다(빼기 = removed_at)', () async {
    final id = await repo.create(const GuidanceContent(title: 't'));
    final a = await repo.addAttachment(_att(id, 'a.m4a'));
    await repo.addAttachment(_att(id, 'b.m4a'));
    await repo.removeAttachment(a.id ?? -1);
    final atts = await repo.getAttachments(id);
    expect(atts.map((x) => x.fileName), ['a.m4a', 'b.m4a']);
    expect(atts.first.isRemoved, isTrue);
    // 목록의 첨부 수는 뺀 것을 세지 않는다
    expect((await repo.getRecord(id))?.attachmentCount, 1);
  });

  test('영구 삭제는 그 기록의 판·첨부만 지우고 파일 이름을 돌려준다', () async {
    final a = await repo.create(const GuidanceContent(title: 'a'));
    final b = await repo.create(const GuidanceContent(title: 'b'));
    await repo.addAttachment(_att(a, 'a1.m4a'));
    await repo.addAttachment(_att(b, 'b1.m4a'));
    await repo.softDelete(a);
    final names = await repo.permanentDelete(a);
    expect(names, ['a1.m4a']);
    expect(await repo.getDeleted(), isEmpty);
    expect(await repo.getRevisions(a), isEmpty);
    expect((await repo.getAttachments(b)).single.fileName, 'b1.m4a');
  });

  test('counts는 삭제한 기록·뺀 첨부까지 센다(초기화 경고용)', () async {
    final a = await repo.create(const GuidanceContent(title: 'a'));
    final x = await repo.addAttachment(_att(a, 'x.m4a'));
    await repo.removeAttachment(x.id ?? -1);
    await repo.softDelete(a);
    final c = await repo.counts();
    expect(c.records, 1);
    expect(c.attachments, 1);
  });
}
```

`test/features/guidance/data/guidance_people_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidancePeopleRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = GuidancePeopleRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  test('여러 명을 한 번에 넣으면 학생으로 들어간다', () async {
    expect(await repo.addNames(['김하늘', '이도윤']), 2);
    final people = await repo.getActive();
    expect(people.map((p) => p.name), ['김하늘', '이도윤']);
    expect(people.every((p) => p.role == PersonRole.student), isTrue);
  });

  test('이미 있는 이름(현재 명단)은 다시 넣지 않는다', () async {
    await repo.addNames(['김하늘']);
    expect(await repo.addNames(['김하늘', '최민서']), 1);
    expect(await repo.getActive(), hasLength(2));
  });

  test('보관하면 현재 명단에서 빠지고 보관 목록에 있다', () async {
    final p = await repo.add(const GuidancePerson(name: '김하늘'));
    await repo.archive(p.id ?? -1);
    expect(await repo.getActive(), isEmpty);
    expect((await repo.getArchived()).single.name, '김하늘');
    await repo.unarchive(p.id ?? -1);
    expect((await repo.getActive()).single.name, '김하늘');
  });

  test('고친 이름·구분·메모가 저장된다', () async {
    final p = await repo.add(const GuidancePerson(name: '보호자'));
    await repo.update(p.copyWith(name: '이도윤 보호자', role: PersonRole.guardian, memo: '어머니'));
    final got = (await repo.getActive()).single;
    expect(got.name, '이도윤 보호자');
    expect(got.role, PersonRole.guardian);
    expect(got.memo, '어머니');
  });

  test('현재 명단은 구분(학생 먼저) → 이름 순이다', () async {
    await repo.add(const GuidancePerson(name: '나보호자', role: PersonRole.guardian));
    await repo.add(const GuidancePerson(name: '하학생'));
    await repo.add(const GuidancePerson(name: '가학생'));
    expect((await repo.getActive()).map((p) => p.name), ['가학생', '하학생', '나보호자']);
  });
}
```

`test/features/guidance/data/guidance_append_only_guard_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `guidance_revisions`는 추가만 한다 — 판을 고치면 "처음에 뭐라고 썼는지"가 사라진다.
/// 저장소 소스를 훑어 UPDATE가 없고 DELETE가 영구 삭제 한 곳뿐인지 본다.
void main() {
  final src = File('lib/features/guidance/data/guidance_repository.dart').readAsStringSync();

  test('판 테이블에 update를 쓰지 않는다', () {
    expect(RegExp(r'update\(\s*DatabaseHelper\.tableGuidanceRevisions').hasMatch(src), isFalse);
    expect(RegExp(r'UPDATE\s+guidance_revisions', caseSensitive: false).hasMatch(src), isFalse);
    expect(src.contains('rawUpdate'), isFalse);
  });

  test('판 테이블 delete는 permanentDelete 안의 한 곳뿐이다', () {
    final hits = RegExp(r'delete\(\s*DatabaseHelper\.tableGuidanceRevisions').allMatches(src).toList();
    expect(hits, hasLength(1));
    final start = src.indexOf('Future<List<String>> permanentDelete(');
    final end = src.indexOf('\n  }\n', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(hits.single.start > start && hits.single.start < end, isTrue);
    expect(src.contains('rawDelete'), isFalse);
  });
}
```

- [ ] **Step 6: 실패를 확인한다**

Run: `flutter test test/features/guidance/data/`
Expected: FAIL — 저장소 파일이 없다.

- [ ] **Step 7: 기록 저장소를 구현한다**

`lib/features/guidance/data/guidance_repository.dart`:

```dart
import '../../../core/database/database_helper.dart';
import '../domain/guidance_content.dart';
import '../domain/guidance_logic.dart';
import '../domain/guidance_models.dart';

/// 지도 기록 저장소 — 기록 몸통·판·첨부.
///
/// ⚠️ **`guidance_revisions`는 추가만 한다.** UPDATE를 쓰지 않고, DELETE는
/// [permanentDelete] 한 곳뿐이다(`guidance_append_only_guard_test.dart`).
class GuidanceRepository {
  GuidanceRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  static const _records = DatabaseHelper.tableGuidanceRecords;
  static const _revisions = DatabaseHelper.tableGuidanceRevisions;
  static const _attachments = DatabaseHelper.tableGuidanceAttachments;

  /// 기록 + 판 1. 기록 시각(`created_at`)은 여기서 한 번 찍고 다시 쓰지 않는다.
  Future<int> create(GuidanceContent content) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final id = await txn.insert(_records, {'created_at': now});
      await txn.insert(_revisions, {
        'record_id': id,
        'revision_no': 1,
        'saved_at': now,
        ...GuidanceRevision.contentToMap(content),
      });
      return id;
    });
  }

  /// 최신 판과 같은 내용이면 아무것도 하지 않고 false.
  Future<bool> saveRevision(int recordId, GuidanceContent content) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        _revisions,
        where: 'record_id = ?',
        whereArgs: [recordId],
        orderBy: 'revision_no DESC',
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final latest = GuidanceRevision.fromMap(rows.first);
      if (sameContent(latest.content, content)) return false;
      await txn.insert(_revisions, {
        'record_id': recordId,
        'revision_no': latest.revisionNo + 1,
        'saved_at': DateTime.now().toIso8601String(),
        ...GuidanceRevision.contentToMap(content),
      });
      return true;
    });
  }

  /// 기록 + 최신 판 + 판 수 + (빼지 않은) 첨부 수. [where]는 `r.` 별칭 기준.
  Future<List<GuidanceRecord>> _query(
    String where,
    List<Object?> args, {
    String orderBy = 'r.id DESC',
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT v.*, r.created_at AS r_created_at, r.deleted_at AS r_deleted_at,
        (SELECT COUNT(*) FROM $_revisions x WHERE x.record_id = r.id) AS rev_count,
        (SELECT COUNT(*) FROM $_attachments a
           WHERE a.record_id = r.id AND a.removed_at IS NULL) AS att_count
      FROM $_records r
      JOIN $_revisions v ON v.record_id = r.id
        AND v.revision_no = (SELECT MAX(y.revision_no) FROM $_revisions y WHERE y.record_id = r.id)
      WHERE $where
      ORDER BY $orderBy
    ''', args);
    return [
      for (final m in rows)
        GuidanceRecord(
          id: m['record_id'] as int,
          createdAt: m['r_created_at'] as String,
          deletedAt: m['r_deleted_at'] as String?,
          latest: GuidanceRevision.fromMap(m),
          revisionCount: m['rev_count'] as int,
          attachmentCount: m['att_count'] as int,
        ),
    ];
  }

  Future<List<GuidanceRecord>> getActive() => _query('r.deleted_at IS NULL', const []);

  Future<List<GuidanceRecord>> getDeleted() => _query(
    'r.deleted_at IS NOT NULL',
    const [],
    orderBy: 'r.deleted_at DESC',
  );

  Future<GuidanceRecord?> getRecord(int id) async {
    final list = await _query('r.id = ?', [id]);
    return list.isEmpty ? null : list.first;
  }

  Future<List<GuidanceRevision>> getRevisions(int recordId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      _revisions,
      where: 'record_id = ?',
      whereArgs: [recordId],
      orderBy: 'revision_no DESC',
    );
    return rows.map(GuidanceRevision.fromMap).toList();
  }

  Future<void> softDelete(int id) => _setDeleted(id, DateTime.now().toIso8601String());

  Future<void> restore(int id) => _setDeleted(id, null);

  Future<void> _setDeleted(int id, String? at) async {
    final db = await _dbHelper.database;
    await db.update(_records, {'deleted_at': at}, where: 'id = ?', whereArgs: [id]);
  }

  /// 사용자가 `삭제한 기록`에서 직접 지울 때만. 판 테이블 DELETE는 **여기 한 곳뿐**이다.
  /// 지운 첨부의 파일 이름을 돌려준다 — 파일은 호출부(`GuidanceActions`)가 지운다.
  Future<List<String>> permanentDelete(int id) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        _attachments,
        columns: ['file_name'],
        where: 'record_id = ?',
        whereArgs: [id],
      );
      await txn.delete(_attachments, where: 'record_id = ?', whereArgs: [id]);
      await txn.delete(DatabaseHelper.tableGuidanceRevisions, where: 'record_id = ?', whereArgs: [id]);
      await txn.delete(_records, where: 'id = ?', whereArgs: [id]);
      return [for (final r in rows) r['file_name'] as String];
    });
  }

  Future<GuidanceAttachment> addAttachment(GuidanceAttachment a) async {
    final db = await _dbHelper.database;
    final id = await db.insert(_attachments, a.toMap());
    return a.copyWith(id: id);
  }

  /// 첨부에서 빼기 — 행과 파일은 남기고 시각만 찍는다(이력에 보인다).
  Future<void> removeAttachment(int attachmentId) async {
    final db = await _dbHelper.database;
    await db.update(
      _attachments,
      {'removed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [attachmentId],
    );
  }

  Future<List<GuidanceAttachment>> getAttachments(int recordId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      _attachments,
      where: 'record_id = ?',
      whereArgs: [recordId],
      orderBy: 'attached_at ASC, id ASC',
    );
    return rows.map(GuidanceAttachment.fromMap).toList();
  }

  Future<({int records, int attachments})> counts() async {
    final db = await _dbHelper.database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM $_records');
    final a = await db.rawQuery('SELECT COUNT(*) AS c FROM $_attachments');
    return (records: r.first['c'] as int, attachments: a.first['c'] as int);
  }
}
```

> `permanentDelete` 안에서만 `DatabaseHelper.tableGuidanceRevisions`를 **풀네임으로** 쓴다 — 가드가 그 문자열을 센다.

- [ ] **Step 8: 명단 저장소를 구현한다**

`lib/features/guidance/data/guidance_people_repository.dart`:

```dart
import '../../../core/database/database_helper.dart';
import '../domain/guidance_models.dart';
import '../domain/guidance_types.dart';

/// 지도 기록 명단. 지우지 않고 **보관**한다 — 옛 기록은 판의 사본으로 이름을 보여 준다.
class GuidancePeopleRepository {
  GuidancePeopleRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  static const _table = DatabaseHelper.tableGuidancePeople;

  /// 구분 순서(학생 먼저) → 이름.
  static const _order =
      "CASE role WHEN 'student' THEN 0 WHEN 'guardian' THEN 1 WHEN 'staff' THEN 2 ELSE 3 END, name";

  Future<GuidancePerson> add(GuidancePerson p) async {
    final db = await _dbHelper.database;
    final id = await db.insert(_table, p.toMap());
    return p.copyWith(id: id);
  }

  /// 붙여넣은 이름을 한 번에. 현재 명단에 같은 이름이 있으면 건너뛴다.
  Future<int> addNames(List<String> names, {PersonRole role = PersonRole.student}) async {
    final db = await _dbHelper.database;
    final existing = {for (final p in await getActive()) p.name};
    var added = 0;
    await db.transaction((txn) async {
      for (final name in names) {
        if (existing.contains(name)) continue;
        await txn.insert(_table, GuidancePerson(name: name, role: role).toMap());
        existing.add(name);
        added++;
      }
    });
    return added;
  }

  Future<void> update(GuidancePerson p) async {
    final id = p.id;
    if (id == null) return;
    final db = await _dbHelper.database;
    final map = p.toMap()..['updated_at'] = DateTime.now().toIso8601String();
    await db.update(_table, map, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> archive(int id) => _setArchived(id, DateTime.now().toIso8601String());

  Future<void> unarchive(int id) => _setArchived(id, null);

  Future<void> _setArchived(int id, String? at) async {
    final db = await _dbHelper.database;
    await db.update(_table, {'archived_at': at}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<GuidancePerson>> getActive() async {
    final db = await _dbHelper.database;
    final rows = await db.query(_table, where: 'archived_at IS NULL', orderBy: _order);
    return rows.map(GuidancePerson.fromMap).toList();
  }

  Future<List<GuidancePerson>> getArchived() async {
    final db = await _dbHelper.database;
    final rows = await db.query(_table, where: 'archived_at IS NOT NULL', orderBy: _order);
    return rows.map(GuidancePerson.fromMap).toList();
  }
}
```

- [ ] **Step 9: 통과를 확인한다**

Run: `flutter test test/features/guidance/ test/core/database/ && flutter analyze lib/features/guidance lib/core/database`
Expected: 전부 PASS, `No issues found!`

- [ ] **Step 10: 커밋**

```bash
git add lib/core/database/database_helper.dart lib/features/guidance/data test/features/guidance/data test/core/database/guidance_migration_test.dart
git commit -m "feat(guidance): DB v10 — 판을 쌓는 기록 저장소와 명단 저장소

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017CsGY18wT1wE3iKefCxJo7"
```

---

### Task 3: 첨부 파일 저장소 · 초기화 · Android 백업 규칙

**Files:**
- Modify: `pubspec.yaml` (`crypto: ^3.0.7` — 지금은 간접 의존. 직접 의존으로 올린다)
- Create: `lib/features/guidance/data/guidance_file_store.dart`
- Modify: `lib/features/settings/data/app_reset_repository.dart`, `lib/features/settings/presentation/widgets/reset_list_tile.dart`, `lib/core/constants/strings/guidance_strings.dart`
- Create: `android/app/src/main/res/xml/backup_rules.xml`, `android/app/src/main/res/xml/data_extraction_rules.xml`
- Modify: `android/app/src/main/AndroidManifest.xml` (`<application>` 속성 둘)
- Test: `test/features/guidance/data/guidance_file_store_test.dart`, `test/features/settings/reset_guidance_test.dart`, `test/features/guidance/android_backup_rules_test.dart`

**Interfaces:**
- Consumes: Task 2 `GuidanceRepository.counts()`, `DatabaseHelper.resetAllData()`.
- Produces:
  - `class StoredFile { final String fileName; final String sha256; final int byteSize; }`
  - `GuidanceFileStore({Future<Directory> Function()? baseDir})`: `static const folder = 'guidance'`, `Future<Directory> dir()`, `Future<StoredFile> importCopy(String sourcePath)`, `Future<String> newRecordingPath()`, `Future<StoredFile> describe(String fileName)`, `Future<File> fileOf(String fileName)`, `Future<void> deleteFiles(Iterable<String> names)`, `Future<void> wipe()`
  - `AppResetRepository({DatabaseHelper? dbHelper, GuidanceFileStore? guidanceFiles})` — `resetAll()`이 DB 뒤 첨부 폴더도 비운다
  - `GuidanceStrings.resetWarning(int records, int attachments)`

- [ ] **Step 1: 의존성을 올린다**

Run: `flutter pub add crypto:^3.0.7`
Expected: `pubspec.yaml`의 dependencies에 `crypto: ^3.0.7`, `pubspec.lock` 변경.

- [ ] **Step 2: 파일 저장소 실패 테스트를 쓴다**

`test/features/guidance/data/guidance_file_store_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';

void main() {
  late Directory base;
  late GuidanceFileStore store;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('guidance_store');
    store = GuidanceFileStore(baseDir: () async => base);
  });
  tearDown(() async {
    if (await base.exists()) await base.delete(recursive: true);
  });

  test('가져온 파일은 바이트 그대로 복사되고 SHA-256이 맞다', () async {
    final src = File('${base.path}/원본 녹음.m4a')..writeAsStringSync('abc');
    final stored = await store.importCopy(src.path);
    // 'abc'의 SHA-256(표준 시험 벡터)
    expect(stored.sha256, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(stored.byteSize, 3);
    expect(stored.fileName.endsWith('.m4a'), isTrue);
    final copied = await store.fileOf(stored.fileName);
    expect(await copied.readAsString(), 'abc');
    expect(copied.parent.path.endsWith(GuidanceFileStore.folder), isTrue);
  });

  test('확장자가 없으면 bin으로 저장한다', () async {
    final src = File('${base.path}/noext')..writeAsStringSync('x');
    expect((await store.importCopy(src.path)).fileName.endsWith('.bin'), isTrue);
  });

  test('녹음 경로는 첨부 폴더 안의 새 m4a다', () async {
    final a = await store.newRecordingPath();
    final b = await store.newRecordingPath();
    expect(a, isNot(b));
    expect(a.endsWith('.m4a'), isTrue);
    expect(File(a).parent.path, (await store.dir()).path);
  });

  test('deleteFiles는 고른 파일만 지운다', () async {
    final keep = await store.importCopy((File('${base.path}/k.jpg')..writeAsStringSync('k')).path);
    final drop = await store.importCopy((File('${base.path}/d.jpg')..writeAsStringSync('d')).path);
    await store.deleteFiles([drop.fileName, '없는파일.m4a']);
    expect(await (await store.fileOf(keep.fileName)).exists(), isTrue);
    expect(await (await store.fileOf(drop.fileName)).exists(), isFalse);
  });

  test('wipe는 첨부 폴더만 비운다', () async {
    final other = File('${base.path}/planroutine.db')..writeAsStringSync('db');
    await store.importCopy((File('${base.path}/x.jpg')..writeAsStringSync('x')).path);
    await store.wipe();
    expect(await Directory('${base.path}/${GuidanceFileStore.folder}').exists(), isFalse);
    expect(await other.exists(), isTrue);
  });
}
```

- [ ] **Step 3: 실패를 확인한다**

Run: `flutter test test/features/guidance/data/guidance_file_store_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 4: 파일 저장소를 구현한다**

`lib/features/guidance/data/guidance_file_store.dart`:

```dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredFile {
  const StoredFile({required this.fileName, required this.sha256, required this.byteSize});
  final String fileName;
  final String sha256;
  final int byteSize;
}

/// 지도 기록 첨부 파일. 앱 전용 `Application Support/guidance/`에 둔다 —
/// 파일 앱·사진 앱에 보이지 않는다.
///
/// **가져온 파일은 변환 없이 바이트 그대로 복사**하고 SHA-256을 남긴다. 사본의 증거능력은
/// 원본과 같음을 보여야 하고, 그 방법으로 해시 비교가 원칙이다(대법원 2022도1864).
///
/// ⚠️ Android에서는 이 폴더가 클라우드 백업에서 빠진다(`res/xml/backup_rules.xml`) —
/// 자동 백업 25MB 상한을 넘으면 DB 백업까지 멈추기 때문이다.
class GuidanceFileStore {
  GuidanceFileStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDir;

  static const folder = 'guidance';

  Future<Directory> dir() async {
    final d = Directory(p.join((await _baseDir()).path, folder));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  var _seq = 0;

  /// 같은 마이크로초에 둘을 만들어도 겹치지 않게 순번을 붙인다.
  String _newName(String ext) =>
      '${DateTime.now().microsecondsSinceEpoch}_${_seq++}.$ext';

  Future<StoredFile> importCopy(String sourcePath) async {
    final rawExt = p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
    final name = _newName(rawExt.isEmpty ? 'bin' : rawExt);
    await File(sourcePath).copy(p.join((await dir()).path, name));
    return describe(name);
  }

  Future<String> newRecordingPath() async => p.join((await dir()).path, _newName('m4a'));

  /// 폴더 안 파일의 해시·크기. 녹음이 끝난 파일에도 쓴다.
  Future<StoredFile> describe(String fileName) async {
    final f = await fileOf(fileName);
    final digest = await sha256.bind(f.openRead()).first;
    return StoredFile(fileName: fileName, sha256: digest.toString(), byteSize: await f.length());
  }

  Future<File> fileOf(String fileName) async => File(p.join((await dir()).path, fileName));

  Future<void> deleteFiles(Iterable<String> names) async {
    for (final n in names) {
      final f = await fileOf(n);
      if (await f.exists()) await f.delete();
    }
  }

  /// 전체 초기화 — 첨부 폴더만 통째로 지운다.
  Future<void> wipe() async {
    final d = Directory(p.join((await _baseDir()).path, folder));
    if (await d.exists()) await d.delete(recursive: true);
  }
}
```

- [ ] **Step 5: 통과를 확인한다**

Run: `flutter test test/features/guidance/data/guidance_file_store_test.dart`
Expected: PASS

- [ ] **Step 6: 초기화 실패 테스트를 쓴다**

`test/features/settings/reset_guidance_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/settings/data/app_reset_repository.dart';
import 'package:planroutine/features/settings/presentation/widgets/reset_list_tile.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  test('전체 초기화는 지도 기록 테이블과 첨부 폴더를 비운다', () async {
    final db = freshDatabaseHelper();
    final base = await Directory.systemTemp.createTemp('reset_guidance');
    final files = GuidanceFileStore(baseDir: () async => base);
    final repo = GuidanceRepository(dbHelper: db);
    await repo.create(const GuidanceContent(title: 't'));
    await files.importCopy((File('${base.path}/a.jpg')..writeAsStringSync('a')).path);

    await AppResetRepository(dbHelper: db, guidanceFiles: files).resetAll();

    expect(await repo.getActive(), isEmpty);
    expect(await Directory('${base.path}/${GuidanceFileStore.folder}').exists(), isFalse);
    await db.close();
    await base.delete(recursive: true);
  });

  test('경고 문구는 건수를 말한다', () {
    expect(GuidanceStrings.resetWarning(3, 2), '지도 기록 3건과 첨부 2개도 지워집니다.');
  });

  testWidgets('지도 기록이 있으면 초기화 확인 창에 건수가 나온다', (tester) async {
    final db = freshDatabaseHelper();
    final repo = GuidanceRepository(dbHelper: db);
    await tester.runAsync(() => repo.create(const GuidanceContent(title: 't')));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: Scaffold(body: ResetListTile())),
      ),
    );
    await tester.tap(find.byType(ListTile));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.textContaining('지도 기록 1건과 첨부 0개'), findsOneWidget);
    await tester.runAsync(db.close);
  });

  testWidgets('지도 기록이 없으면 경고 줄이 없다', (tester) async {
    final db = freshDatabaseHelper();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(GuidanceRepository(dbHelper: db))],
        child: const MaterialApp(home: Scaffold(body: ResetListTile())),
      ),
    );
    await tester.tap(find.byType(ListTile));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    // 기본 문구에도 `지도 기록`이 들어 있으므로 경고 줄만의 낱말로 찾는다
    expect(find.textContaining('건과 첨부'), findsNothing);
    await tester.runAsync(db.close);
  });
}
```

> 이 테스트는 Task 4의 `guidance_providers.dart`를 쓴다. **이 Task에서 `guidanceRepositoryProvider` 한 줄짜리 provider 파일을 먼저 만든다**(Step 7). Task 4가 같은 파일을 키운다.

- [ ] **Step 7: provider 파일의 첫 줄들을 만든다**

`lib/features/guidance/presentation/providers/guidance_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/guidance_file_store.dart';
import '../../data/guidance_people_repository.dart';
import '../../data/guidance_repository.dart';

final guidanceRepositoryProvider = Provider<GuidanceRepository>((ref) => GuidanceRepository());

final guidancePeopleRepositoryProvider = Provider<GuidancePeopleRepository>(
  (ref) => GuidancePeopleRepository(),
);

final guidanceFileStoreProvider = Provider<GuidanceFileStore>((ref) => GuidanceFileStore());

/// 지도 기록이 바뀌었다는 신호. 목록·보기·이력이 watch해 다시 읽는다.
final guidanceChangedProvider = StateProvider<int>((ref) => 0);
```

- [ ] **Step 8: 초기화를 고친다**

`lib/core/constants/strings/guidance_strings.dart` 끝(닫는 `}` 앞)에:

```dart
  // 전체 초기화 경고
  static String resetWarning(int records, int attachments) =>
      '지도 기록 $records건과 첨부 $attachments개도 지워집니다.';
```

`lib/features/settings/data/app_reset_repository.dart` 전체:

```dart
import '../../../core/database/database_helper.dart';
import '../../guidance/data/guidance_file_store.dart';

/// 앱 전체 데이터 초기화 저장소
///
/// 테이블(캘린더 이벤트, 확정 일정, 가져온 일정, 포스트잇, 지도 기록 넷)의 데이터를 한 번에
/// 삭제하고, 지도 기록 첨부 폴더도 비운다. DELETE 로직은 [DatabaseHelper.resetAllData]에 위임한다.
class AppResetRepository {
  final DatabaseHelper _dbHelper;
  final GuidanceFileStore _guidanceFiles;

  AppResetRepository({DatabaseHelper? dbHelper, GuidanceFileStore? guidanceFiles})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance,
      _guidanceFiles = guidanceFiles ?? GuidanceFileStore();

  /// DB를 먼저 비운다 — 파일을 먼저 지우고 DB가 실패하면 행만 남고 파일이 없는 첨부가 생긴다.
  Future<void> resetAll() async {
    await _dbHelper.resetAllData();
    await _guidanceFiles.wipe();
  }
}
```

`lib/features/settings/presentation/widgets/reset_list_tile.dart`의 `_onTap` 첫 줄을 바꾼다(import에 `../../../guidance/presentation/providers/guidance_providers.dart` 추가):

```dart
  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    // 지도 기록은 되돌릴 수 없는 근거 자료다 — 지워진다는 사실을 건수로 따로 말한다.
    final counts = await ref.read(guidanceRepositoryProvider).counts();
    if (!context.mounted) return;
    final message = counts.records == 0
        ? SettingsStrings.resetAllConfirmMessage
        : '${SettingsStrings.resetAllConfirmMessage}\n\n'
              '${GuidanceStrings.resetWarning(counts.records, counts.attachments)}';
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: SettingsStrings.resetAllConfirmTitle,
      message: message,
      confirmLabel: SettingsStrings.resetAllConfirm,
      confirmColor: AppColors.error,
    );
    if (!confirmed) return;
    await ref.read(appResetProvider.notifier).resetAll();
  }
```

`lib/features/settings/presentation/providers/settings_providers.dart`의 `resetAll()`에서 `_ref.read(memoRevisionProvider.notifier).state++;` 다음 줄에 (import `../../../guidance/presentation/providers/guidance_providers.dart`):

```dart
      _ref.read(guidanceChangedProvider.notifier).state++;
```

`SettingsStrings.resetAllConfirmMessage` 첫 줄을 `'일정·캘린더 이벤트·포스트잇·지도 기록이 모두 삭제됩니다.\n'`로 바꾼다.

- [ ] **Step 9: 초기화 테스트 통과를 확인한다**

Run: `flutter test test/features/settings/`
Expected: PASS(기존 설정 테스트 포함 — 확인 문구를 문자열 그대로 찾던 테스트가 깨지면 `SettingsStrings.resetAllConfirmMessage` 상수를 참조하도록 고친다. 선언 수는 줄이지 않는다).

- [ ] **Step 10: Android 백업 규칙을 쓴다**

`android/app/src/main/res/xml/backup_rules.xml` (Android 11 이하, `fullBackupContent`):

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- 지도 기록 첨부(녹음·사진)는 클라우드 백업에서 뺀다.
     자동 백업은 앱당 25MB가 상한이고 넘으면 백업 전체가 멈춘다 — 그러면 일정 DB까지 백업되지 않는다.
     exclude만 적으면 나머지는 전부 포함된다. -->
<full-backup-content>
    <exclude domain="file" path="guidance/" />
</full-backup-content>
```

`android/app/src/main/res/xml/data_extraction_rules.xml` (Android 12+):

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- 클라우드 백업에서만 뺀다. 기기 간 직접 이전(device-transfer)에는 크기 상한이 없어 포함한다. -->
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="file" path="guidance/" />
    </cloud-backup>
</data-extraction-rules>
```

`android/app/src/main/AndroidManifest.xml`의 `<application ... android:allowBackup="true">`에 속성 둘을 더한다:

```xml
        android:allowBackup="true"
        android:fullBackupContent="@xml/backup_rules"
        android:dataExtractionRules="@xml/data_extraction_rules">
```

`test/features/guidance/android_backup_rules_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';

/// 첨부 폴더 이름과 백업 제외 경로가 어긋나면 녹음이 클라우드 백업에 들어가
/// 25MB 상한을 넘기고, 그 순간 일정 DB 백업까지 멈춘다 — 증상 없이.
void main() {
  const res = 'android/app/src/main/res/xml';
  final excluded = 'path="${GuidanceFileStore.folder}/"';

  test('두 백업 규칙 파일이 첨부 폴더를 뺀다', () {
    for (final f in ['backup_rules.xml', 'data_extraction_rules.xml']) {
      expect(File('$res/$f').readAsStringSync(), contains(excluded), reason: f);
    }
  });

  test('매니페스트가 두 규칙 파일을 가리킨다', () {
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(m, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(m, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
  });
}
```

Run: `flutter test test/features/guidance/android_backup_rules_test.dart`
Expected: PASS

- [ ] **Step 11: 25MB 상한을 공식 문서로 확인한다**

https://developer.android.com/identity/data/autobackup 를 열어 "25MB" 상한과 "초과 시 백업하지 않는다"는 문장을 찾는다. 문장이 다르면(상한이 없어졌거나 동작이 다르면) 작업을 멈추고 보고한다 — 스펙의 결정(A) 근거가 바뀐다.

- [ ] **Step 12: Android 빌드가 리소스를 받는지 확인한다**

Run: `flutter build apk --debug 2>&1 | tail -5`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 13: 커밋**

```bash
git add pubspec.yaml pubspec.lock lib/features/guidance lib/features/settings lib/core/constants/strings android/app/src/main test/features/guidance test/features/settings/reset_guidance_test.dart
git commit -m "feat(guidance): 첨부 원본 보존(SHA-256)·초기화 범위·Android 백업 제외

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017CsGY18wT1wE3iKefCxJo7"
```

---
### Task 4: provider · 등록부 · 중첩 셸 라우트 · 목록 화면

**Files:**
- Modify: `lib/features/guidance/presentation/providers/guidance_providers.dart` (Task 3의 네 줄에 목록·필터·`GuidanceActions`를 더한다)
- Create: `lib/features/guidance/presentation/screens/guidance_list_screen.dart`, `lib/features/guidance/presentation/widgets/guidance_badges.dart`, `lib/features/guidance/presentation/widgets/guidance_record_tile.dart`
- Modify: `lib/core/modules/app_module.dart` (`ModuleIds.guidance`), `lib/core/modules/module_catalog.dart` (`guidanceTab` + 항목), `lib/core/router/app_router.dart` (경로 상수 + 중첩 `ShellRoute`), `lib/core/constants/strings/guidance_strings.dart`
- Test: `test/core/modules/module_catalog_test.dart`(배포 id 목록·항목 검사 추가), `test/features/guidance/presentation/guidance_list_screen_test.dart`, `test/features/guidance/presentation/guidance_actions_test.dart`, `test/core/theme/guidance_badge_contrast_test.dart`

**Interfaces:**
- Consumes: Task 1 순수 함수·모델, Task 2 저장소, Task 3 `GuidanceFileStore`·`guidanceChangedProvider`.
- Produces:
  - `ModuleIds.guidance = 'guidance'`, `const guidanceTab`
  - `AppRoutes.guidance = '/guidance'`, `AppRoutes.guidanceNew = '/guidance/new'`, `AppRoutes.guidancePeople = '/guidance/people'`, `AppRoutes.guidanceTrash = '/guidance/trash'`, `static String guidanceRecord(int id)`, `static String guidanceEdit(int id)`, `static String guidanceHistory(int id)`
  - 중첩 `ShellRoute` — 이후 Task가 `GoRoute(path: AppRoutes.guidance, routes: [...])`의 `routes`에 하위 경로를 더한다(상대 경로 `new`·`record/:id`·`people`·`trash`)
  - provider: `guidanceRecordsProvider`, `guidanceDeletedRecordsProvider`, `guidanceRecordProvider(int)`, `guidanceRevisionsProvider(int)`, `guidanceAttachmentsProvider(int)`, `guidancePeopleProvider`, `guidanceArchivedPeopleProvider`, `guidanceKindFilterProvider`, `guidancePersonFilterProvider`, `visibleGuidanceRecordsProvider`, `guidanceActionsProvider`
  - `GuidanceActions`: `create(GuidanceContent) → Future<int>`, `save(int, GuidanceContent) → Future<bool>`, `delete(int)`, `restore(int)`, `permanentDelete(int)`, `attachImported({required int recordId, required String sourcePath, required AttachmentType type, String? originalName}) → Future<GuidanceAttachment>`, `attachRecording({required int recordId, required String path, required int durationMs, required DateTime startedAt}) → Future<GuidanceAttachment>`, `removeAttachment(int)`, `addPerson(GuidancePerson) → Future<GuidancePerson>`, `addNames(List<String>) → Future<int>`, `updatePerson(GuidancePerson)`, `archivePerson(int)`, `unarchivePerson(int)`
  - `GuidanceKindBadge(kind)`, `GuidanceStatusBadge(status)` — 정적 `colorOf`로 색을 노출
  - `GuidanceRecordTile({required GuidanceRecord record, required DateTime now, VoidCallback? onTap})`
  - `GuidanceListScreen` 키: `addKey`, `peopleKey`, `trashKey`, `personFilterKey`, `kindFilterKey(GuidanceKind?)`, `rowKey(int)`

- [ ] **Step 1: 문자열을 더한다**

`guidance_strings.dart` 끝에:

```dart
  // 목록
  static const newRecord = '새 기록';
  static const peopleTitle = '명단 관리';
  static const trashTitle = '삭제한 기록';
  static const kindAll = '전체';
  static const personAll = '사람: 전체';
  static String personLabel(String name) => '사람: $name';
  static const personPickerTitle = '사람으로 찾기';
  static const personPickerEmpty = '기록에 등장한 사람이 아직 없습니다';
  static const empty = '아직 기록이 없습니다';
  static const emptyScope =
      '학교 단계의 생활지도·교육활동 침해를 남기는 곳입니다. 교육청으로 이관된 뒤의 조사는 전담조사관이 맡습니다.';
  static const noMatch = '조건에 맞는 기록이 없습니다';
  static String revisedTimes(int n) => '수정 $n회';
```

- [ ] **Step 2: 등록부·라우트 실패 테스트를 쓴다**

`test/core/modules/module_catalog_test.dart`의 `_shippedIds`에 `ModuleIds.guidance,`를 더하고, `main()` 안 끝에 테스트 하나를 더한다:

```dart
  test('지도 기록은 고정이 아닌 탭형이고 /guidance로 간다', () {
    final g = moduleCatalog.firstWhere((m) => m.id == ModuleIds.guidance);
    expect(g.placement, ModulePlacement.tab);
    expect(g.fixed, isFalse);
    expect(g.tab?.route, AppRoutes.guidance);
    expect(g.settingsRoute, isNull);
    expect(ModuleIds.guidance, 'guidance');
  });
```

Run: `flutter test test/core/modules/module_catalog_test.dart`
Expected: FAIL — `ModuleIds.guidance` 미정의.

- [ ] **Step 3: 등록부와 라우트를 더한다**

`lib/core/modules/app_module.dart`의 `ModuleIds`에 `static const guidance = 'guidance';`.

`lib/core/router/app_router.dart`의 `AppRoutes`에:

```dart
  static const guidance = '/guidance';
  static const guidanceNew = '/guidance/new';
  static const guidancePeople = '/guidance/people';
  static const guidanceTrash = '/guidance/trash';
  static String guidanceRecord(int id) => '/guidance/record/$id';
  static String guidanceEdit(int id) => '/guidance/record/$id/edit';
  static String guidanceHistory(int id) => '/guidance/record/$id/history';
```

같은 파일의 바깥 `ShellRoute` `routes` 목록에서 memo `GoRoute` 바로 뒤에(import `../../features/guidance/presentation/screens/guidance_list_screen.dart`):

```dart
        // 지도 기록(선택 탭). 탭의 모든 화면이 이 **중첩 셸** 아래에 있다 — 다른 탭으로
        // `go`하면 셸이 dispose되어 잠금 상태가 함께 사라진다(Task 5가 builder를 잠금 게이트로 바꾼다).
        ShellRoute(
          builder: (context, state, child) => child,
          routes: [
            GoRoute(
              path: AppRoutes.guidance,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: GuidanceListScreen()),
              routes: const [],
            ),
          ],
        ),
```

> `routes: const []`는 이후 Task가 하위 경로를 넣는 자리다. 넣을 때 `const`를 뗀다.

`lib/core/modules/module_catalog.dart`에서 `memoTab` 아래:

```dart
const guidanceTab = ModuleTab(
  route: AppRoutes.guidance,
  icon: Icons.lock_outline,
  activeIcon: Icons.lock,
  label: GuidanceStrings.tabLabel,
);
```

`moduleCatalog` 끝(memo 항목 뒤):

```dart
  AppModule(
    id: ModuleIds.guidance,
    name: GuidanceStrings.title,
    description: GuidanceStrings.moduleDescription,
    icon: Icons.lock_outline,
    placement: ModulePlacement.tab,
    tab: guidanceTab,
  ),
```

- [ ] **Step 4: provider와 `GuidanceActions`를 쓴다**

`guidance_providers.dart`를 아래로 키운다(Task 3의 네 정의는 그대로 둔다):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/guidance_file_store.dart';
import '../../data/guidance_people_repository.dart';
import '../../data/guidance_repository.dart';
import '../../domain/guidance_content.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';

final guidanceRepositoryProvider = Provider<GuidanceRepository>((ref) => GuidanceRepository());

final guidancePeopleRepositoryProvider = Provider<GuidancePeopleRepository>(
  (ref) => GuidancePeopleRepository(),
);

final guidanceFileStoreProvider = Provider<GuidanceFileStore>((ref) => GuidanceFileStore());

/// 지도 기록이 바뀌었다는 신호. 목록·보기·이력이 watch해 다시 읽는다.
final guidanceChangedProvider = StateProvider<int>((ref) => 0);

final guidanceRecordsProvider = FutureProvider.autoDispose<List<GuidanceRecord>>((ref) {
  ref.watch(guidanceChangedProvider);
  return ref.watch(guidanceRepositoryProvider).getActive();
});

final guidanceDeletedRecordsProvider = FutureProvider.autoDispose<List<GuidanceRecord>>((ref) {
  ref.watch(guidanceChangedProvider);
  return ref.watch(guidanceRepositoryProvider).getDeleted();
});

final guidanceRecordProvider = FutureProvider.autoDispose.family<GuidanceRecord?, int>((ref, id) {
  ref.watch(guidanceChangedProvider);
  return ref.watch(guidanceRepositoryProvider).getRecord(id);
});

final guidanceRevisionsProvider =
    FutureProvider.autoDispose.family<List<GuidanceRevision>, int>((ref, id) {
      ref.watch(guidanceChangedProvider);
      return ref.watch(guidanceRepositoryProvider).getRevisions(id);
    });

final guidanceAttachmentsProvider =
    FutureProvider.autoDispose.family<List<GuidanceAttachment>, int>((ref, id) {
      ref.watch(guidanceChangedProvider);
      return ref.watch(guidanceRepositoryProvider).getAttachments(id);
    });

final guidancePeopleProvider = FutureProvider.autoDispose<List<GuidancePerson>>((ref) {
  ref.watch(guidanceChangedProvider);
  return ref.watch(guidancePeopleRepositoryProvider).getActive();
});

final guidanceArchivedPeopleProvider = FutureProvider.autoDispose<List<GuidancePerson>>((ref) {
  ref.watch(guidanceChangedProvider);
  return ref.watch(guidancePeopleRepositoryProvider).getArchived();
});

/// 목록의 구분 필터. null = 전체. 탭을 떠나면 풀린다(autoDispose).
final guidanceKindFilterProvider = StateProvider.autoDispose<GuidanceKind?>((ref) => null);

/// 목록의 사람 필터. null = 전체.
final guidancePersonFilterProvider = StateProvider.autoDispose<Participant?>((ref) => null);

final visibleGuidanceRecordsProvider =
    Provider.autoDispose<AsyncValue<List<GuidanceRecord>>>((ref) {
      final kind = ref.watch(guidanceKindFilterProvider);
      final person = ref.watch(guidancePersonFilterProvider);
      return ref
          .watch(guidanceRecordsProvider)
          .whenData((list) => filterRecords(sortRecords(list), kind: kind, person: person));
    });

final guidanceActionsProvider = Provider<GuidanceActions>((ref) => GuidanceActions(ref));

/// 지도 기록의 모든 변경은 여기를 거친다 — 끝에 신호를 올려 화면들이 다시 읽게 한다.
class GuidanceActions {
  GuidanceActions(this._ref);

  final Ref _ref;

  GuidanceRepository get _repo => _ref.read(guidanceRepositoryProvider);
  GuidancePeopleRepository get _people => _ref.read(guidancePeopleRepositoryProvider);
  GuidanceFileStore get _files => _ref.read(guidanceFileStoreProvider);

  void _changed() => _ref.read(guidanceChangedProvider.notifier).state++;

  Future<int> create(GuidanceContent content) async {
    final id = await _repo.create(content);
    _changed();
    return id;
  }

  /// 같은 내용이면 판을 만들지 않고 false.
  Future<bool> save(int id, GuidanceContent content) async {
    final saved = await _repo.saveRevision(id, content);
    if (saved) _changed();
    return saved;
  }

  Future<void> delete(int id) async {
    await _repo.softDelete(id);
    _changed();
  }

  Future<void> restore(int id) async {
    await _repo.restore(id);
    _changed();
  }

  /// DB를 먼저 지우고 그 기록의 파일만 지운다.
  Future<void> permanentDelete(int id) async {
    final names = await _repo.permanentDelete(id);
    await _files.deleteFiles(names);
    _changed();
  }

  /// 가져온 파일을 첨부 폴더로 그대로 복사하고 해시를 남긴다.
  /// `captured_at`은 비운다 — 고르기 창이 넘겨주는 것은 임시 사본이라 그 파일의 시각은
  /// 원본의 시각이 아니다. 원래 파일 이름은 남긴다.
  Future<GuidanceAttachment> attachImported({
    required int recordId,
    required String sourcePath,
    required AttachmentType type,
    String? originalName,
  }) async {
    final stored = await _files.importCopy(sourcePath);
    final a = await _repo.addAttachment(
      GuidanceAttachment(
        recordId: recordId,
        type: type,
        source: AttachmentSource.imported,
        fileName: stored.fileName,
        originalName: originalName,
        sha256: stored.sha256,
        byteSize: stored.byteSize,
        attachedAt: DateTime.now().toIso8601String(),
      ),
    );
    _changed();
    return a;
  }

  /// 녹음은 처음부터 첨부 폴더 안에 쓰인다([GuidanceFileStore.newRecordingPath]).
  Future<GuidanceAttachment> attachRecording({
    required int recordId,
    required String path,
    required int durationMs,
    required DateTime startedAt,
  }) async {
    final stored = await _files.describe(p.basename(path));
    final a = await _repo.addAttachment(
      GuidanceAttachment(
        recordId: recordId,
        type: AttachmentType.audio,
        source: AttachmentSource.recorded,
        fileName: stored.fileName,
        sha256: stored.sha256,
        byteSize: stored.byteSize,
        durationMs: durationMs,
        capturedAt: startedAt.toIso8601String(),
        attachedAt: DateTime.now().toIso8601String(),
      ),
    );
    _changed();
    return a;
  }

  Future<void> removeAttachment(int attachmentId) async {
    await _repo.removeAttachment(attachmentId);
    _changed();
  }

  Future<GuidancePerson> addPerson(GuidancePerson person) async {
    final saved = await _people.add(person);
    _changed();
    return saved;
  }

  Future<int> addNames(List<String> names) async {
    final n = await _people.addNames(names);
    _changed();
    return n;
  }

  Future<void> updatePerson(GuidancePerson person) async {
    await _people.update(person);
    _changed();
  }

  Future<void> archivePerson(int id) async {
    await _people.archive(id);
    _changed();
  }

  Future<void> unarchivePerson(int id) async {
    await _people.unarchive(id);
    _changed();
  }
}
```

- [ ] **Step 5: `GuidanceActions` 테스트를 쓴다**

`test/features/guidance/presentation/guidance_actions_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late Directory base;
  late ProviderContainer c;
  late GuidanceFileStore files;

  setUp(() async {
    db = freshDatabaseHelper();
    base = await Directory.systemTemp.createTemp('guidance_actions');
    files = GuidanceFileStore(baseDir: () async => base);
    c = ProviderContainer(
      overrides: [
        guidanceRepositoryProvider.overrideWithValue(GuidanceRepository(dbHelper: db)),
        guidancePeopleRepositoryProvider.overrideWithValue(GuidancePeopleRepository(dbHelper: db)),
        guidanceFileStoreProvider.overrideWithValue(files),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await db.close();
    await base.delete(recursive: true);
  });

  test('가져온 사진은 원래 이름과 해시를 갖고 붙는다', () async {
    final actions = c.read(guidanceActionsProvider);
    final id = await actions.create(const GuidanceContent(title: 't'));
    final src = File('${base.path}/IMG_0001.HEIC')..writeAsStringSync('abc');
    final a = await actions.attachImported(
      recordId: id,
      sourcePath: src.path,
      type: AttachmentType.image,
      originalName: 'IMG_0001.HEIC',
    );
    expect(a.originalName, 'IMG_0001.HEIC');
    expect(a.sha256, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(a.source, AttachmentSource.imported);
    expect(a.capturedAt, isNull);
  });

  test('녹음은 첨부 폴더 안의 파일로 붙고 시작 시각을 남긴다', () async {
    final actions = c.read(guidanceActionsProvider);
    final id = await actions.create(const GuidanceContent(title: 't'));
    final path = await files.newRecordingPath();
    File(path).writeAsStringSync('abc');
    final started = DateTime(2026, 10, 2, 15, 41);
    final a = await actions.attachRecording(
      recordId: id,
      path: path,
      durationMs: 768000,
      startedAt: started,
    );
    expect(a.source, AttachmentSource.recorded);
    expect(a.durationMs, 768000);
    expect(a.capturedAt, started.toIso8601String());
  });

  test('영구 삭제는 그 기록의 파일만 지운다', () async {
    final actions = c.read(guidanceActionsProvider);
    final keepId = await actions.create(const GuidanceContent(title: 'keep'));
    final dropId = await actions.create(const GuidanceContent(title: 'drop'));
    final keep = await actions.attachImported(
      recordId: keepId,
      sourcePath: (File('${base.path}/k.jpg')..writeAsStringSync('k')).path,
      type: AttachmentType.image,
    );
    final drop = await actions.attachImported(
      recordId: dropId,
      sourcePath: (File('${base.path}/d.jpg')..writeAsStringSync('d')).path,
      type: AttachmentType.image,
    );
    await actions.delete(dropId);
    await actions.permanentDelete(dropId);
    expect(await (await files.fileOf(keep.fileName)).exists(), isTrue);
    expect(await (await files.fileOf(drop.fileName)).exists(), isFalse);
  });

  test('변경마다 신호가 오른다', () async {
    final actions = c.read(guidanceActionsProvider);
    final before = c.read(guidanceChangedProvider);
    await actions.create(const GuidanceContent(title: 't'));
    expect(c.read(guidanceChangedProvider), before + 1);
  });
}
```

Run: `flutter test test/features/guidance/presentation/guidance_actions_test.dart`
Expected: PASS(Step 4를 이미 썼으므로).

- [ ] **Step 6: 배지·행 위젯을 쓴다**

`lib/features/guidance/presentation/widgets/guidance_badges.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/guidance_types.dart';

/// 테두리형 배지 — 글자색과 테두리가 같다. 대비는 글자색 대 배경으로 재면 된다.
class _OutlineBadge extends StatelessWidget {
  const _OutlineBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(AppSizes.radius4),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class GuidanceKindBadge extends StatelessWidget {
  const GuidanceKindBadge(this.kind, {super.key});
  final GuidanceKind kind;

  static Color colorOf(GuidanceKind kind) =>
      kind == GuidanceKind.infringement ? AppColors.inkRed : AppColors.info;

  @override
  Widget build(BuildContext context) => _OutlineBadge(label: kind.label, color: colorOf(kind));
}

/// `진행 중`은 기본 상태라 아무것도 그리지 않는다.
class GuidanceStatusBadge extends StatelessWidget {
  const GuidanceStatusBadge(this.status, {super.key});
  final GuidanceStatus status;

  static Color colorOf(GuidanceStatus status) =>
      status == GuidanceStatus.closedAtSchool ? AppColors.inkGreen : AppColors.sub;

  @override
  Widget build(BuildContext context) => switch (status) {
    GuidanceStatus.open => const SizedBox.shrink(),
    GuidanceStatus.closedAtSchool => _OutlineBadge(
      label: GuidanceStrings.statusClosedShort,
      color: colorOf(status),
    ),
    GuidanceStatus.transferred => _OutlineBadge(
      label: GuidanceStrings.statusTransferredShort,
      color: colorOf(status),
    ),
  };
}
```

`lib/features/guidance/presentation/widgets/guidance_record_tile.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import 'guidance_badges.dart';

/// 목록 한 줄. 배경·테두리는 `Material`이 진다 — 잉크가 보이게(ListTile 규칙과 같은 이유).
class GuidanceRecordTile extends StatelessWidget {
  const GuidanceRecordTile({super.key, required this.record, required this.now, this.onTap});

  final GuidanceRecord record;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = record.content;
    final names = c.participants.map((p) => p.displayName).join(' · ');
    final meta = TextStyle(fontSize: 14, color: AppColors.sub);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(formatOccurred(c, now: now), style: meta)),
                  if (record.attachmentCount > 0) ...[
                    Icon(Icons.attach_file, size: AppSizes.iconSmall, color: AppColors.sub),
                    Text('${record.attachmentCount}', style: meta),
                    const SizedBox(width: AppSizes.spacing8),
                  ],
                  if (record.revisionCount > 1)
                    Text(GuidanceStrings.revisedTimes(record.revisionCount - 1), style: meta),
                ],
              ),
              const SizedBox(height: AppSizes.spacing4),
              Row(
                children: [
                  GuidanceKindBadge(c.kind),
                  if (c.status != GuidanceStatus.open) ...[
                    const SizedBox(width: AppSizes.spacing4),
                    GuidanceStatusBadge(c.status),
                  ],
                  const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
              if (names.isNotEmpty) ...[
                const SizedBox(height: AppSizes.spacing4),
                Text(names, maxLines: 1, overflow: TextOverflow.ellipsis, style: meta),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: 목록 화면 실패 테스트를 쓴다**

`test/features/guidance/presentation/guidance_list_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_list_screen.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: GuidanceListScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('기록이 없으면 빈 상태와 범위 안내가 보인다', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.empty), findsOneWidget);
    expect(find.text(GuidanceStrings.emptyScope), findsOneWidget);
  });

  testWidgets('사건 시각이 최근인 기록이 위에 오고 수정 횟수가 보인다', (tester) async {
    await tester.runAsync(() async {
      final a = await repo.create(
        GuidanceContent(title: '오래된 일', occurredAt: DateTime(2026, 9, 25, 12, 40)),
      );
      await repo.create(GuidanceContent(title: '최근 일', occurredAt: DateTime(2026, 10, 2, 15, 30)));
      await repo.saveRevision(
        a,
        GuidanceContent(title: '오래된 일', facts: '덧붙임', occurredAt: DateTime(2026, 9, 25, 12, 40)),
      );
    });
    await pump(tester);
    final recent = tester.getTopLeft(find.text('최근 일'));
    final old = tester.getTopLeft(find.text('오래된 일'));
    expect(recent.dy < old.dy, isTrue);
    expect(find.text(GuidanceStrings.revisedTimes(1)), findsOneWidget);
  });

  testWidgets('구분 필터로 교육활동 침해만 본다', (tester) async {
    await tester.runAsync(() async {
      await repo.create(const GuidanceContent(title: '복도 다툼'));
      await repo.create(
        const GuidanceContent(title: '학부모 폭언', kind: GuidanceKind.infringement),
      );
    });
    await pump(tester);
    await tester.tap(find.byKey(GuidanceListScreen.kindFilterKey(GuidanceKind.infringement)));
    await settle(tester);
    expect(find.text('학부모 폭언'), findsOneWidget);
    expect(find.text('복도 다툼'), findsNothing);
  });

  testWidgets('사람으로 고르면 그 사람이 나온 기록만 보인다', (tester) async {
    await tester.runAsync(() async {
      await repo.create(
        const GuidanceContent(title: '하늘 건', participants: [Participant(personId: 1, name: '김하늘')]),
      );
      await repo.create(
        const GuidanceContent(title: '서준 건', participants: [Participant(name: '박서준', memo: '5반')]),
      );
    });
    await pump(tester);
    await tester.tap(find.byKey(GuidanceListScreen.personFilterKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('박서준 · 5반'));
    await settle(tester);
    expect(find.text('서준 건'), findsOneWidget);
    expect(find.text('하늘 건'), findsNothing);
    expect(find.text(GuidanceStrings.personLabel('박서준')), findsOneWidget);
  });

  testWidgets('이관한 기록에는 이관 배지가, 진행 중에는 상태 배지가 없다', (tester) async {
    await tester.runAsync(() async {
      await repo.create(
        const GuidanceContent(title: '넘긴 일', status: GuidanceStatus.transferred),
      );
      await repo.create(const GuidanceContent(title: '진행 일'));
    });
    await pump(tester);
    expect(find.text(GuidanceStrings.statusTransferredShort), findsOneWidget);
    expect(find.text(GuidanceStrings.statusClosedShort), findsNothing);
  });

  testWidgets('320pt에서도 필터 줄이 넘치지 않는다', (tester) async {
    await pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });
}
```

`test/core/theme/guidance_badge_contrast_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/widgets/guidance_badges.dart';

import '../../helpers/contrast.dart';

/// 배지는 테두리형이라 글자색이 곧 배지색이다 — 카드(surface) 위에서 4.5:1을 지킨다.
void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  for (final b in Brightness.values) {
    test('$b: 구분·상태 배지 글자가 카드 위에서 4.5:1 이상', () {
      AppColors.applyBrightness(b);
      final colors = {
        for (final k in GuidanceKind.values) k.name: GuidanceKindBadge.colorOf(k),
        for (final s in GuidanceStatus.values) s.name: GuidanceStatusBadge.colorOf(s),
      };
      for (final e in colors.entries) {
        expect(contrastRatio(e.value, AppColors.surface), greaterThanOrEqualTo(4.5),
            reason: e.key);
      }
    });
  }
}
```

Run: `flutter test test/features/guidance/presentation/guidance_list_screen_test.dart test/core/theme/guidance_badge_contrast_test.dart`
Expected: 목록 테스트는 FAIL(화면 없음). 대비 테스트는 PASS여야 한다 — 실패하면 그 테마의 색을 바꾸지 말고 **멈추고 보고한다**(토큰 변경은 전역 영향 — 사전 확인 대상).

- [ ] **Step 8: 목록 화면을 구현한다**

`lib/features/guidance/presentation/screens/guidance_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';
import '../providers/guidance_providers.dart';
import '../widgets/guidance_record_tile.dart';

/// 지도 기록 탭 첫 화면. 잠금은 이 화면이 아니라 셸(`GuidanceLockGate`)이 진다.
class GuidanceListScreen extends ConsumerWidget {
  const GuidanceListScreen({super.key});

  static const addKey = Key('guidance_add');
  static const peopleKey = Key('guidance_people');
  static const trashKey = Key('guidance_trash');
  static const personFilterKey = Key('guidance_person_filter');
  static Key kindFilterKey(GuidanceKind? kind) => Key('guidance_kind_${kind?.dbValue ?? 'all'}');
  static Key rowKey(int id) => Key('guidance_row_$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(guidanceRecordsProvider).valueOrNull;
    final visible = ref.watch(visibleGuidanceRecordsProvider).valueOrNull ?? const <GuidanceRecord>[];
    final kind = ref.watch(guidanceKindFilterProvider);
    final person = ref.watch(guidancePersonFilterProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(GuidanceStrings.eyebrow, style: AppTextStyles.eyebrow),
            const SizedBox(height: 2),
            Text(GuidanceStrings.title, style: AppTextStyles.heading),
          ],
        ),
        actions: [
          IconButton(
            key: peopleKey,
            tooltip: GuidanceStrings.peopleTitle,
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => context.push(AppRoutes.guidancePeople),
          ),
          IconButton(
            key: trashKey,
            tooltip: GuidanceStrings.trashTitle,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.push(AppRoutes.guidanceTrash),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: addKey,
        tooltip: GuidanceStrings.newRecord,
        backgroundColor: AppColors.goldFill,
        foregroundColor: AppColors.onGold,
        onPressed: () => context.push(AppRoutes.guidanceNew),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spacing16, AppSizes.spacing4, AppSizes.spacing16, AppSizes.spacing12,
            ),
            child: Wrap(
              spacing: AppSizes.spacing8,
              runSpacing: AppSizes.spacing8,
              children: [
                ActionChip(
                  key: personFilterKey,
                  avatar: const Icon(Icons.person_outline, size: AppSizes.iconSmall),
                  label: Text(
                    person == null ? GuidanceStrings.personAll : GuidanceStrings.personLabel(person.name),
                  ),
                  onPressed: () => _pickPerson(context, ref, all ?? const []),
                ),
                for (final k in <GuidanceKind?>[null, ...GuidanceKind.values])
                  ChoiceChip(
                    key: kindFilterKey(k),
                    label: Text(k?.label ?? GuidanceStrings.kindAll),
                    selected: kind == k,
                    onSelected: (_) => ref.read(guidanceKindFilterProvider.notifier).state = k,
                  ),
              ],
            ),
          ),
          Expanded(
            child: all == null
                ? const SizedBox.shrink()
                : all.isEmpty
                    ? _empty()
                    : visible.isEmpty
                        ? Center(child: Text(GuidanceStrings.noMatch, style: AppTextStyles.bodyM))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSizes.spacing16, 0, AppSizes.spacing16, AppSizes.spacing48 * 2,
                            ),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.cardGap),
                            itemBuilder: (context, i) {
                              final r = visible[i];
                              return GuidanceRecordTile(
                                key: rowKey(r.id),
                                record: r,
                                now: now,
                                onTap: () => context.push(AppRoutes.guidanceRecord(r.id)),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 48, color: AppColors.faint),
          const SizedBox(height: AppSizes.spacing12),
          Text(GuidanceStrings.empty, style: AppTextStyles.bodyL),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            GuidanceStrings.emptyScope,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
          ),
        ],
      ),
    ),
  );

  /// 기록에 등장한 사람(명단 밖 포함) 중 하나를 고른다. `(null,)`은 "전체", 시트를 그냥 닫으면 null.
  Future<void> _pickPerson(BuildContext context, WidgetRef ref, List<GuidanceRecord> records) async {
    final candidates = collectParticipants(records);
    final picked = await showModalBottomSheet<(Participant?,)>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(GuidanceStrings.personPickerTitle, style: AppTextStyles.heading)),
            ListTile(
              title: const Text(GuidanceStrings.kindAll),
              onTap: () => Navigator.pop(ctx, (null,)),
            ),
            if (candidates.isEmpty)
              const ListTile(title: Text(GuidanceStrings.personPickerEmpty)),
            for (final p in candidates)
              ListTile(
                title: Text(p.displayName),
                subtitle: Text(p.role.label),
                onTap: () => Navigator.pop(ctx, (p,)),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    ref.read(guidancePersonFilterProvider.notifier).state = picked.$1;
  }
}
```

- [ ] **Step 9: 통과를 확인한다**

Run: `flutter test test/features/guidance/ test/core/modules/ test/core/theme/guidance_badge_contrast_test.dart && flutter analyze`
Expected: 전부 PASS, `No issues found!`

- [ ] **Step 10: 커밋**

```bash
git add lib/core/modules lib/core/router/app_router.dart lib/core/constants/strings/guidance_strings.dart lib/features/guidance test/core/modules test/core/theme/guidance_badge_contrast_test.dart test/features/guidance
git commit -m "feat(guidance): 지도 기록 탭 등록 — 목록·구분/사람 필터·중첩 셸 라우트

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017CsGY18wT1wE3iKefCxJo7"
```

---

### Task 5: 잠금 — 기기 인증 · 시스템 창 가드 · FLAG_SECURE · 루트 내비게이터 가드

**Files:**
- Modify: `pubspec.yaml` (`local_auth: ^3.0.2`)
- Create: `lib/features/guidance/presentation/lock/system_sheet_guard.dart`, `lib/features/guidance/presentation/lock/device_authenticator.dart`, `lib/features/guidance/presentation/lock/secure_window.dart`, `lib/features/guidance/presentation/lock/guidance_lock_gate.dart`
- Modify: `lib/core/router/app_router.dart` (중첩 셸 builder), `lib/shared/widgets/confirm_dialog.dart` (`useRootNavigator`), `lib/core/constants/strings/guidance_strings.dart`
- Modify: `android/app/src/main/kotlin/com/planroutine/app/MainActivity.kt`, `android/app/src/main/res/values/styles.xml`, `android/app/src/main/res/values-night/styles.xml`, `ios/Runner/Info.plist`
- Test: `test/features/guidance/lock/guidance_lock_gate_test.dart`, `test/features/guidance/lock/system_sheet_guard_test.dart`, `test/features/guidance/lock/lock_native_wiring_test.dart`, `test/features/guidance/guidance_root_navigator_guard_test.dart`

**Interfaces:**
- Consumes: Task 4 라우트·셸.
- Produces:
  - `SystemSheetGuard.run<T>(Future<T> Function() task)`, `SystemSheetGuard.shouldIgnore(AppLifecycleState)`, `@visibleForTesting SystemSheetGuard.reset()`, `@visibleForTesting static DateTime Function() clock`
  - `enum AuthOutcome { success, failed, noCredentials }`, `abstract class DeviceAuthenticator { Future<AuthOutcome> authenticate(String reason); }`, `deviceAuthenticatorProvider`
  - `abstract class SecureWindow { Future<void> setSecure(bool on); }`, `secureWindowProvider`, 채널 `planroutine/secure_window` 메서드 `setSecure(bool)`
  - `GuidanceLockGate({required Widget child})` — 키 `coverKey`, `unlockKey`, `openWithoutLockKey`
  - `ConfirmDialog.show(..., bool useRootNavigator = true)`

- [ ] **Step 1: 의존성과 문자열**

Run: `flutter pub add local_auth:^3.0.2`

`guidance_strings.dart` 끝에:

```dart
  // 잠금
  static const unlockReason = '지도 기록을 열려면 본인 확인이 필요합니다';
  static const lockedTitle = '지도 기록은 잠겨 있어요';
  static const lockedBody = '다른 탭으로 옮기거나 앱을 떠나면 다시 잠깁니다.';
  static const unlock = '잠금 해제';
  static const noCredentialsTitle = '기기 암호가 설정되어 있지 않아요';
  static const noCredentialsBody =
      '기기 암호나 Face ID·지문을 설정해야 기록이 보호됩니다. 설정하지 않아도 쓸 수는 있습니다.';
  static const openWithoutLock = '잠금 없이 열기';
```

- [ ] **Step 2: 시스템 창 가드 실패 테스트**

`test/features/guidance/lock/system_sheet_guard_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/presentation/lock/system_sheet_guard.dart';

void main() {
  var now = DateTime(2026, 10, 3, 9);
  setUp(() {
    SystemSheetGuard.reset();
    SystemSheetGuard.clock = () => now;
  });
  tearDown(() {
    SystemSheetGuard.reset();
    SystemSheetGuard.clock = DateTime.now;
  });

  test('시스템 창이 떠 있는 동안에는 비활성·백그라운드를 모두 무시한다', () async {
    final done = Completer<void>();
    final running = SystemSheetGuard.run(() => done.future);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.inactive), isTrue);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.paused), isTrue);
    done.complete();
    await running;
  });

  test('끝난 직후 잠깐은 비활성만 무시하고 백그라운드는 잠근다', () async {
    await SystemSheetGuard.run(() async {});
    now = now.add(const Duration(milliseconds: 300));
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.inactive), isTrue);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.paused), isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.inactive), isFalse);
  });

  test('작업이 실패해도 가드는 풀린다', () async {
    await expectLater(SystemSheetGuard.run(() async => throw StateError('x')), throwsStateError);
    now = now.add(const Duration(seconds: 5));
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.paused), isFalse);
  });
}
```

Run: `flutter test test/features/guidance/lock/system_sheet_guard_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 3: 가드·인증·보안 창을 구현한다**

`lib/features/guidance/presentation/lock/system_sheet_guard.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 앱이 **직접 연** 시스템 창(Face ID·사진/파일 고르기·마이크 권한) 동안 잠그지 않게 하는 표시.
///
/// ⚠️ 그 창들은 앱을 `inactive`(Android는 `paused`)로 만든다. 이 가드가 없으면
/// Face ID 창이 뜨는 순간 다시 잠겨 **무한 반복**되고, 사진을 고르러 갔다 오면 잠긴다.
/// 시스템 창을 여는 호출은 반드시 [run]으로 감싼다.
abstract final class SystemSheetGuard {
  static int _depth = 0;
  static DateTime? _endedAt;

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// 창이 닫힌 뒤 늦게 도착하는 `inactive`를 흘려보내는 여유. `paused`에는 적용하지 않는다 —
  /// 고르기 직후 홈으로 나가면 잠겨야 한다.
  static const grace = Duration(milliseconds: 800);

  static Future<T> run<T>(Future<T> Function() task) async {
    _depth++;
    try {
      return await task();
    } finally {
      _depth--;
      _endedAt = clock();
    }
  }

  static bool shouldIgnore(AppLifecycleState state) {
    if (_depth > 0) return true;
    final ended = _endedAt;
    return state == AppLifecycleState.inactive &&
        ended != null &&
        clock().difference(ended) < grace;
  }

  @visibleForTesting
  static void reset() {
    _depth = 0;
    _endedAt = null;
  }
}
```

`lib/features/guidance/presentation/lock/device_authenticator.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

enum AuthOutcome { success, failed, noCredentials }

/// 기기 인증 한 번. 테스트에서 바꿔 끼우려고 인터페이스로 둔다.
abstract class DeviceAuthenticator {
  Future<AuthOutcome> authenticate(String reason);
}

/// Face ID·지문, 없으면 기기 암호(`biometricOnly: false`).
class LocalDeviceAuthenticator implements DeviceAuthenticator {
  LocalDeviceAuthenticator([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    try {
      // 암호조차 없는 기기는 지원하지 않는 것으로 나온다.
      if (!await _auth.isDeviceSupported()) return AuthOutcome.noCredentials;
      final ok = await _auth.authenticate(localizedReason: reason);
      return ok ? AuthOutcome.success : AuthOutcome.failed;
    } on LocalAuthException catch (e) {
      return e.code == LocalAuthExceptionCode.noCredentialsSet
          ? AuthOutcome.noCredentials
          : AuthOutcome.failed;
    } on PlatformException {
      return AuthOutcome.failed;
    }
  }
}

final deviceAuthenticatorProvider = Provider<DeviceAuthenticator>(
  (ref) => LocalDeviceAuthenticator(),
);
```

`lib/features/guidance/presentation/lock/secure_window.dart`:

```dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Android `FLAG_SECURE` — 최근 앱 화면에 내용이 찍히지 않고 스크린샷도 막힌다.
/// iOS에는 같은 플래그가 없어 아무것도 하지 않는다(잠금 덮개가 그 몫을 한다).
abstract class SecureWindow {
  Future<void> setSecure(bool on);
}

class PlatformSecureWindow implements SecureWindow {
  /// `MainActivity.kt`의 `SECURE_CHANNEL`과 같아야 한다(`lock_native_wiring_test.dart`).
  static const channel = MethodChannel('planroutine/secure_window');

  @override
  Future<void> setSecure(bool on) async {
    if (!Platform.isAndroid) return;
    try {
      await channel.invokeMethod<void>('setSecure', on);
    } on PlatformException {
      // 막지 못해도 잠금 덮개는 동작한다 — 기능을 멈추지 않는다.
    } on MissingPluginException {
      // 같은 이유.
    }
  }
}

final secureWindowProvider = Provider<SecureWindow>((ref) => PlatformSecureWindow());
```

Run: `flutter test test/features/guidance/lock/system_sheet_guard_test.dart`
Expected: PASS

- [ ] **Step 4: 잠금 게이트 실패 테스트**

`test/features/guidance/lock/guidance_lock_gate_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/presentation/lock/device_authenticator.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_lock_gate.dart';
import 'package:planroutine/features/guidance/presentation/lock/secure_window.dart';
import 'package:planroutine/features/guidance/presentation/lock/system_sheet_guard.dart';

class FakeAuth implements DeviceAuthenticator {
  final outcomes = <AuthOutcome>[];
  var calls = 0;
  @override
  Future<AuthOutcome> authenticate(String reason) async {
    calls++;
    return outcomes.isEmpty ? AuthOutcome.failed : outcomes.removeAt(0);
  }
}

class FakeSecure implements SecureWindow {
  final log = <bool>[];
  @override
  Future<void> setSecure(bool on) async => log.add(on);
}

void main() {
  late FakeAuth auth;
  late FakeSecure secure;

  setUp(() {
    SystemSheetGuard.reset();
    auth = FakeAuth();
    secure = FakeSecure();
  });

  Future<void> pump(WidgetTester tester, {Widget? child}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthenticatorProvider.overrideWithValue(auth),
          secureWindowProvider.overrideWithValue(secure),
        ],
        child: MaterialApp(
          home: GuidanceLockGate(
            child: child ??
                const Scaffold(body: TextField(key: Key('field'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void lifecycle(WidgetTester tester, AppLifecycleState s) =>
      tester.binding.handleAppLifecycleStateChanged(s);

  testWidgets('들어오면 자동으로 인증하고, 성공하면 덮개가 걷힌다', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    await pump(tester);
    expect(auth.calls, 1);
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('실패하면 덮개가 남고 잠금 해제 버튼으로 다시 시도한다', (tester) async {
    auth.outcomes.addAll([AuthOutcome.failed, AuthOutcome.success]);
    await pump(tester);
    expect(find.byKey(GuidanceLockGate.coverKey), findsOneWidget);
    expect(find.text(GuidanceStrings.lockedTitle), findsOneWidget);
    await tester.tap(find.byKey(GuidanceLockGate.unlockKey));
    await tester.pumpAndSettle();
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('잠긴 동안 아래 화면은 눌리지 않는다', (tester) async {
    var tapped = false;
    await pump(
      tester,
      child: Scaffold(body: Center(child: TextButton(onPressed: () => tapped = true, child: const Text('아래')))),
    );
    await tester.tap(find.text('아래'), warnIfMissed: false);
    expect(tapped, isFalse);
  });

  testWidgets('앱을 떠나면 잠기고, 다시 풀면 쓰던 글이 그대로다', (tester) async {
    auth.outcomes.addAll([AuthOutcome.success, AuthOutcome.success]);
    await pump(tester);
    await tester.enterText(find.byKey(const Key('field')), '쓰던 글');
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.paused);
    await tester.pump();
    expect(find.byKey(GuidanceLockGate.coverKey), findsOneWidget);
    lifecycle(tester, AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(auth.calls, 2, reason: '돌아오면 자동으로 다시 묻는다');
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
    expect(find.text('쓰던 글'), findsOneWidget);
  });

  testWidgets('시스템 창(사진 고르기 등) 동안의 비활성·백그라운드는 잠그지 않는다', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    await pump(tester);
    final picker = Completer<void>();
    final running = SystemSheetGuard.run(() => picker.future);
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.paused);
    lifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    picker.complete();
    await running;
    await tester.pump();
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('인증을 취소한 뒤 돌아와도 다시 묻지 않는다(무한 반복 방지)', (tester) async {
    auth.outcomes.add(AuthOutcome.failed);
    await pump(tester);
    // Face ID 창이 닫히며 오는 resumed — 가드 안에서 일어난 비활성 뒤의 복귀다
    lifecycle(tester, AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
  });

  testWidgets('기기 암호가 없으면 안내하고 잠금 없이 열 수 있다', (tester) async {
    auth.outcomes.add(AuthOutcome.noCredentials);
    await pump(tester);
    expect(find.text(GuidanceStrings.noCredentialsTitle), findsOneWidget);
    await tester.tap(find.byKey(GuidanceLockGate.openWithoutLockKey));
    await tester.pumpAndSettle();
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('보이는 동안 FLAG_SECURE를 켜고 떠나면 끈다', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    await pump(tester);
    expect(secure.log, [true]);
    await tester.pumpWidget(const SizedBox());
    expect(secure.log, [true, false]);
  });
}
```

Run: `flutter test test/features/guidance/lock/guidance_lock_gate_test.dart`
Expected: FAIL — 게이트 없음.

- [ ] **Step 5: 게이트를 구현한다**

`lib/features/guidance/presentation/lock/guidance_lock_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'device_authenticator.dart';
import 'secure_window.dart';
import 'system_sheet_guard.dart';

/// 지도 기록 탭 전체를 감싸는 잠금. 중첩 셸의 builder가 쓴다 — 다른 탭으로 `go`하면
/// 셸과 함께 dispose되어 다음에 들어올 때 다시 잠겨 있다.
///
/// **덮개는 화면을 덮기만 한다.** 아래 화면을 dispose하지 않으므로 잠금을 풀면 쓰던 글이
/// 그대로다. 잠긴 동안에는 아래 화면이 눌리지 않고(`IgnorePointer`) 스크린리더도
/// 읽지 않는다(`ExcludeSemantics`).
class GuidanceLockGate extends ConsumerStatefulWidget {
  const GuidanceLockGate({super.key, required this.child});

  final Widget child;

  static const coverKey = Key('guidance_lock_cover');
  static const unlockKey = Key('guidance_unlock');
  static const openWithoutLockKey = Key('guidance_open_without_lock');

  @override
  ConsumerState<GuidanceLockGate> createState() => _GuidanceLockGateState();
}

class _GuidanceLockGateState extends ConsumerState<GuidanceLockGate> with WidgetsBindingObserver {
  var _unlocked = false;
  var _noCredentials = false;
  var _authing = false;

  /// 생명주기 때문에 잠겼다 — 돌아오면(resumed) 자동으로 다시 묻는다.
  /// 인증 창을 취소한 뒤의 resumed에서는 묻지 않는다(그 비활성은 가드가 흘려보냈으므로 이 값이 안 켜진다).
  var _askOnResume = false;

  late final SecureWindow _secure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _secure = ref.read(secureWindowProvider);
    _secure.setSecure(true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _secure.setSecure(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_askOnResume) {
        _askOnResume = false;
        _authenticate();
      }
      return;
    }
    if (state == AppLifecycleState.detached) return;
    if (SystemSheetGuard.shouldIgnore(state)) return;
    _askOnResume = true;
    if (_unlocked) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _unlocked = false);
    }
  }

  Future<void> _authenticate() async {
    if (_authing || _unlocked || !mounted) return;
    _authing = true;
    final outcome = await SystemSheetGuard.run(
      () => ref.read(deviceAuthenticatorProvider).authenticate(GuidanceStrings.unlockReason),
    );
    _authing = false;
    if (!mounted) return;
    setState(() {
      switch (outcome) {
        case AuthOutcome.success:
          _unlocked = true;
          _noCredentials = false;
        case AuthOutcome.noCredentials:
          _noCredentials = true;
        case AuthOutcome.failed:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = !_unlocked;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: locked,
          child: IgnorePointer(ignoring: locked, child: widget.child),
        ),
        if (locked)
          _LockCover(
            key: GuidanceLockGate.coverKey,
            noCredentials: _noCredentials,
            onUnlock: _authenticate,
            onOpenAnyway: () => setState(() => _unlocked = true),
          ),
      ],
    );
  }
}

class _LockCover extends StatelessWidget {
  const _LockCover({
    super.key,
    required this.noCredentials,
    required this.onUnlock,
    required this.onOpenAnyway,
  });

  final bool noCredentials;
  final VoidCallback onUnlock;
  final VoidCallback onOpenAnyway;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: AppColors.gold),
              const SizedBox(height: AppSizes.spacing16),
              Text(
                noCredentials ? GuidanceStrings.noCredentialsTitle : GuidanceStrings.lockedTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: AppSizes.spacing8),
              Text(
                noCredentials ? GuidanceStrings.noCredentialsBody : GuidanceStrings.lockedBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyM.copyWith(color: AppColors.sub),
              ),
              const SizedBox(height: AppSizes.spacing24),
              FilledButton.icon(
                key: GuidanceLockGate.unlockKey,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.goldFill,
                  foregroundColor: AppColors.onGold,
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                ),
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open),
                label: const Text(GuidanceStrings.unlock),
              ),
              if (noCredentials) ...[
                const SizedBox(height: AppSizes.spacing8),
                TextButton(
                  key: GuidanceLockGate.openWithoutLockKey,
                  onPressed: onOpenAnyway,
                  child: const Text(GuidanceStrings.openWithoutLock),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
```

Run: `flutter test test/features/guidance/lock/guidance_lock_gate_test.dart`
Expected: PASS(8건).

- [ ] **Step 6: 셸 builder를 게이트로 바꾼다**

`lib/core/router/app_router.dart`의 지도 기록 `ShellRoute`(import `../../features/guidance/presentation/lock/guidance_lock_gate.dart`):

```dart
        ShellRoute(
          builder: (context, state, child) => GuidanceLockGate(child: child),
```

주석의 `(Task 5가 builder를 잠금 게이트로 바꾼다)`를 지운다.

- [ ] **Step 7: ConfirmDialog에 인자를 더하고 루트 내비게이터 가드를 쓴다**

`lib/shared/widgets/confirm_dialog.dart`의 `show` 인자 끝에 `bool useRootNavigator = true,`를 더하고 `showDialog<bool>(`에 `useRootNavigator: useRootNavigator,`를 넘긴다. 기존 호출부는 기본값이라 바뀌지 않는다.

그 위 주석에 한 줄:

```dart
/// 지도 기록 화면에서는 `useRootNavigator: false`로 부른다 — 루트에 뜨면 잠금 덮개 **위**에 남는다.
```

`test/features/guidance/guidance_root_navigator_guard_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 지도 기록 화면의 대화상자·시간 고르기는 탭의 중첩 내비게이터에 떠야 한다. 루트에 뜨면
/// 앱이 잠겨도 덮개 **위**에 남아 내용(제목·이름)이 보인다.
void main() {
  const calls = ['showDialog(', 'showDialog<', 'ConfirmDialog.show(', 'showDatePicker(', 'showTimePicker('];

  test('지도 기록 화면의 대화상자는 모두 useRootNavigator: false다', () {
    final files = Directory('lib/features/guidance/presentation')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final call in calls) {
        var i = src.indexOf(call);
        while (i >= 0) {
          final window = src.substring(i, (i + 700).clamp(0, src.length));
          expect(window.contains('useRootNavigator: false'), isTrue, reason: '${f.path} @$i $call');
          i = src.indexOf(call, i + call.length);
        }
      }
    }
  });
}
```

Run: `flutter test test/features/guidance/guidance_root_navigator_guard_test.dart test/shared`
Expected: PASS(아직 지도 기록에 대화상자가 없어 통과 — 이후 Task가 쓸 때 지킨다).

- [ ] **Step 8: 네이티브 배선**

`android/app/src/main/kotlin/com/planroutine/app/MainActivity.kt`:
- `import io.flutter.embedding.android.FlutterActivity` → `import io.flutter.embedding.android.FlutterFragmentActivity`
- `import android.view.WindowManager` 추가
- `class MainActivity : FlutterActivity()` → `class MainActivity : FlutterFragmentActivity()`
- 클래스 KDoc 끝에 한 문단:

```kotlin
 * `FlutterFragmentActivity`인 이유: 지도 기록 잠금(`local_auth`)이 생체 인증 창을 띄우려면
 * FragmentActivity가 필요하다. 부모를 바꿔도 공유 채널 동작은 같다 — 에뮬레이터에서
 * cold-start·running 공유를 다시 태워 확인했다(Task 10).
```

- `configureFlutterEngine`의 `handleIntent(intent)` 앞에:

```kotlin
        // 지도 기록 탭이 보이는 동안 최근 앱 화면·스크린샷에 내용이 찍히지 않게 한다.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        if (call.arguments == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
```

- `companion object`에 `const val SECURE_CHANNEL = "planroutine/secure_window"`를 더한다(주석: `Dart `PlatformSecureWindow.channel`과 같아야 한다.`).

`android/app/src/main/res/values/styles.xml`의 `LaunchTheme` parent를 `Theme.AppCompat.Light.NoActionBar`로, `values-night/styles.xml`의 `LaunchTheme` parent를 `Theme.AppCompat.NoActionBar`로 바꾼다(local_auth: Android 8 이하에서 AppCompat 테마가 아니면 인증 창이 크래시한다. `NormalTheme`은 그대로).

`ios/Runner/Info.plist`의 `<dict>` 안(알파벳 순서 자리)에:

```xml
	<key>NSFaceIDUsageDescription</key>
	<string>지도 기록의 잠금을 풀 때 Face ID를 사용합니다.</string>
```

`test/features/guidance/lock/lock_native_wiring_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/presentation/lock/secure_window.dart';

void main() {
  final kt = File('android/app/src/main/kotlin/com/planroutine/app/MainActivity.kt').readAsStringSync();

  test('MainActivity는 FragmentActivity다(local_auth 요구)', () {
    expect(kt, contains('class MainActivity : FlutterFragmentActivity()'));
  });

  test('보안 창 채널 이름이 양쪽에서 같다', () {
    expect(kt, contains('"${PlatformSecureWindow.channel.name}"'));
    expect(kt, contains('FLAG_SECURE'));
  });

  test('LaunchTheme가 두 테마 모두 AppCompat이다', () {
    for (final f in ['values', 'values-night']) {
      final xml = File('android/app/src/main/res/$f/styles.xml').readAsStringSync();
      expect(RegExp(r'name="LaunchTheme" parent="Theme\.AppCompat').hasMatch(xml), isTrue, reason: f);
    }
  });

  test('iOS Face ID 사용 문구가 있다', () {
    expect(File('ios/Runner/Info.plist').readAsStringSync(), contains('NSFaceIDUsageDescription'));
  });
}
```

Run: `flutter test test/features/guidance/lock/`
Expected: PASS

- [ ] **Step 9: 두 플랫폼이 빌드되는지 확인한다**

Run: `flutter build apk --debug 2>&1 | tail -5`
Expected: `✓ Built ...app-debug.apk`. **`Theme.AppCompat` 리소스를 못 찾는다는 오류가 나면** `android/app/build.gradle.kts`의 `dependencies { }`에 `implementation("androidx.appcompat:appcompat:1.7.0")`를 더하고 다시 빌드한다.

Run: `flutter build ios --simulator --debug 2>&1 | tail -5`
Expected: `✓ Built build/ios/iphonesimulator/Runner.app`

- [ ] **Step 10: 전체 테스트와 분석**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`, 전부 PASS.

- [ ] **Step 11: 커밋**

```bash
git add pubspec.yaml pubspec.lock lib android/app/src/main ios/Runner/Info.plist test/features/guidance
git commit -m "feat(guidance): 탭 잠금 — 기기 인증·시스템 창 가드·FLAG_SECURE

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017CsGY18wT1wE3iKefCxJo7"
```

---
### Task 6: 기록 쓰기·고치기 화면 · 사건 시각 입력 · 관련인 고르기

**Files:**
- Create: `lib/features/guidance/presentation/screens/guidance_edit_screen.dart`, `lib/features/guidance/presentation/widgets/occurred_input.dart`, `lib/features/guidance/presentation/widgets/participant_picker_sheet.dart`
- Modify: `lib/core/router/app_router.dart` (하위 경로 `new`, `record/:id/edit`), `lib/core/constants/strings/guidance_strings.dart`
- Test: `test/features/guidance/presentation/guidance_edit_screen_test.dart`, `test/features/guidance/presentation/participant_picker_sheet_test.dart`

**Interfaces:**
- Consumes: Task 4 `guidanceActionsProvider`·`guidanceRecordProvider`·`guidancePeopleProvider`, Task 1 `GuidanceContent`·`sameContent`·`formatStamp`.
- Produces:
  - `GuidanceEditScreen({int? recordId})` — 키 `saveKey`, `cancelKey`, `titleKey`, `placeKey`, `factsKey`, `quotesKey`, `actionsKey`, `addPersonKey`, `kindKey(GuidanceKind)`, `statusKey(GuidanceStatus)`. **Task 8이 `_attachmentsSection`을 이 화면에 더한다** — 그때 쓰는 내부 메서드 `Future<int> _ensureRecord()`를 이 Task에서 만든다.
  - `OccurredInput({required OccurredPrecision precision, DateTime? at, String? text, required ValueChanged<OccurredValue> onChanged})`, `class OccurredValue { precision, at, text }` — 키 `precisionKey(OccurredPrecision)`, `dateKey`, `timeKey`, `approxKey`
  - `showParticipantPicker(BuildContext, {required List<Participant> exclude}) → Future<Participant?>` — 키 `ParticipantPickerSheet.queryKey`, `outsideKey`, `addToRosterKey`, `confirmKey`, `roleKey(PersonRole)`, `memoKey`
- 라우트: `/guidance/new` → `GuidanceEditScreen()`, `/guidance/record/:id/edit` → `GuidanceEditScreen(recordId: id)`

- [ ] **Step 1: 문자열을 더한다**

```dart
  // 기록 쓰기
  static const editNewTitle = '새 기록';
  static const editTitle = '기록 고치기';
  static const save = '저장';
  static const cancel = '취소';
  static const untitled = '제목 없음';
  static const titleRequired = '제목을 적어 주세요';
  static const labelKind = '구분';
  static const labelStatus = '진행 상태';
  static const labelOccurred = '사건 시각';
  static const labelCreated = '기록 시각';
  static const createdOnSave = '저장할 때 자동으로 남아요';
  static const labelTitle = '제목';
  static const labelPlace = '장소';
  static const labelParticipants = '관련인';
  static const labelFacts = '경과';
  static const labelQuotes = '들은 말';
  static const labelActions = '판단·조치';
  static const approxHint = '예: 3월 초~여름방학 전';
  static const pickDate = '날짜';
  static const pickTime = '시각';
  static const addPerson = '사람 추가';
  static const participantsHint =
      '가해·피해를 나누어 적지 않아요. 판단이 나오기 전의 기록이 결론처럼 읽힐 수 있어서입니다. 필요하면 경과에 사실대로 적어 주세요.';
  static const quotesHint = '누가 무엇이라고 말했는지 들은 그대로 적어 주세요.';
  static const actionsHint = '어떻게 지도했는지, 보호자 연락·학교 보고·이관을 언제 했는지 적어 주세요.';
  static const discardTitle = '저장하지 않고 나갈까요?';
  static const discardMessage = '고친 내용이 사라집니다. 이미 저장된 판은 그대로 남습니다.';
  static const discardConfirm = '나가기';

  // 관련인 고르기
  static const pickerTitle = '관련인 추가';
  static const pickerQueryHint = '이름';
  static String outsideRoster(String name) => '‘$name’ 명단 밖 이름으로 넣기';
  static const outsideMemoHint = '소속·관계 (예: 5반, 민준 어머니)';
  static const addToRoster = '명단에도 추가';
  static const pickerConfirm = '넣기';
```

- [ ] **Step 2: 관련인 고르기 실패 테스트**

`test/features/guidance/presentation/participant_picker_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/widgets/participant_picker_sheet.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidancePeopleRepository people;

  setUp(() {
    db = freshDatabaseHelper();
    people = GuidancePeopleRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  Future<Participant?> open(WidgetTester tester, {List<Participant> exclude = const []}) async {
    Participant? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidancePeopleRepositoryProvider.overrideWithValue(people)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showParticipantPicker(context, exclude: exclude),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('명단에서 고르면 그 사람의 사본이 돌아온다', (tester) async {
    await tester.runAsync(() => people.add(const GuidancePerson(name: '김하늘', memo: '3반')));
    Participant? got;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidancePeopleRepositoryProvider.overrideWithValue(people)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => got = await showParticipantPicker(context, exclude: const []),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await settle(tester);
    await tester.tap(find.text('김하늘'));
    await tester.pumpAndSettle();
    expect(got?.name, '김하늘');
    expect(got?.personId, isNotNull);
    expect(got?.memo, '3반');
  });

  testWidgets('이미 넣은 사람은 목록에 나오지 않는다', (tester) async {
    final p = await tester.runAsync(() => people.add(const GuidancePerson(name: '김하늘')));
    await open(tester, exclude: [Participant(personId: p?.id, name: '김하늘')]);
    await settle(tester);
    expect(find.text('김하늘'), findsNothing);
  });

  testWidgets('명단 밖 이름은 구분·소속을 붙여 넣고, 명단에도 더할 수 있다', (tester) async {
    Participant? got;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidancePeopleRepositoryProvider.overrideWithValue(people)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => got = await showParticipantPicker(context, exclude: const []),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await settle(tester);
    await tester.enterText(find.byKey(ParticipantPickerSheet.queryKey), '박서준');
    await tester.pump();
    await tester.tap(find.byKey(ParticipantPickerSheet.outsideKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ParticipantPickerSheet.memoKey), '5반');
    await tester.tap(find.byKey(ParticipantPickerSheet.addToRosterKey));
    await tester.pump();
    await tester.tap(find.byKey(ParticipantPickerSheet.confirmKey));
    await settle(tester);
    expect(got?.name, '박서준');
    expect(got?.memo, '5반');
    expect(got?.role, PersonRole.student);
    expect(got?.personId, isNotNull, reason: '명단에 더했으면 id가 붙는다');
    final roster = await tester.runAsync(people.getActive);
    expect(roster?.single.name, '박서준');
  });

  testWidgets('명단에 더하지 않으면 id 없이 돌아온다', (tester) async {
    Participant? got;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidancePeopleRepositoryProvider.overrideWithValue(people)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => got = await showParticipantPicker(context, exclude: const []),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await settle(tester);
    await tester.enterText(find.byKey(ParticipantPickerSheet.queryKey), '이도윤 보호자');
    await tester.pump();
    await tester.tap(find.byKey(ParticipantPickerSheet.outsideKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ParticipantPickerSheet.roleKey(PersonRole.guardian)));
    await tester.tap(find.byKey(ParticipantPickerSheet.confirmKey));
    await settle(tester);
    expect(got?.personId, isNull);
    expect(got?.role, PersonRole.guardian);
  });
}
```

> 첫 테스트를 제외한 셋은 `open` 헬퍼 대신 결과를 받으려고 같은 모양을 직접 쓴다 — `open`은 결과를 기다리지 않고 돌아오므로 "고르지 않는" 테스트에만 쓴다.

Run: `flutter test test/features/guidance/presentation/participant_picker_sheet_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 3: 관련인 고르기를 구현한다**

`lib/features/guidance/presentation/widgets/participant_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';
import '../providers/guidance_providers.dart';

/// 관련인 한 명을 고른다. 명단에서 고르거나, 명단 밖 이름을 구분·소속과 함께 넣는다.
/// 시트는 지도 기록의 중첩 내비게이터에 뜬다(`showModalBottomSheet` 기본값) — 잠금 덮개 아래.
Future<Participant?> showParticipantPicker(
  BuildContext context, {
  required List<Participant> exclude,
}) => showModalBottomSheet<Participant>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ParticipantPickerSheet(exclude: exclude),
);

class ParticipantPickerSheet extends ConsumerStatefulWidget {
  const ParticipantPickerSheet({super.key, required this.exclude});

  final List<Participant> exclude;

  static const queryKey = Key('picker_query');
  static const outsideKey = Key('picker_outside');
  static const memoKey = Key('picker_memo');
  static const addToRosterKey = Key('picker_add_to_roster');
  static const confirmKey = Key('picker_confirm');
  static Key roleKey(PersonRole r) => Key('picker_role_${r.dbValue}');

  @override
  ConsumerState<ParticipantPickerSheet> createState() => _ParticipantPickerSheetState();
}

class _ParticipantPickerSheetState extends ConsumerState<ParticipantPickerSheet> {
  final _query = TextEditingController();
  final _memo = TextEditingController();
  var _composing = false;
  var _role = PersonRole.student;
  var _addToRoster = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _confirmOutside() async {
    if (_busy) return;
    final name = _query.text.trim();
    if (name.isEmpty) return;
    final memo = _memo.text.trim().isEmpty ? null : _memo.text.trim();
    var result = Participant(name: name, role: _role, memo: memo);
    if (_addToRoster) {
      setState(() => _busy = true);
      final saved = await ref
          .read(guidanceActionsProvider)
          .addPerson(GuidancePerson(name: name, role: _role, memo: memo));
      result = saved.toParticipant();
    }
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom < 0 ? 0 : bottom),
      child: _composing ? _outsideForm() : _list(),
    );
  }

  Widget _list() {
    final q = _query.text.trim();
    final roster = ref.watch(guidancePeopleProvider).valueOrNull ?? const <GuidancePerson>[];
    final candidates = [
      for (final p in roster)
        if (!widget.exclude.any((e) => sameParticipant(e, p.toParticipant())) &&
            (q.isEmpty || p.name.contains(q)))
          p,
    ];
    final exact = roster.any((p) => p.name == q);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          ListTile(title: Text(GuidanceStrings.pickerTitle, style: AppTextStyles.heading)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
            child: TextField(
              key: ParticipantPickerSheet.queryKey,
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(hintText: GuidanceStrings.pickerQueryHint),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (q.isNotEmpty && !exact)
                  ListTile(
                    key: ParticipantPickerSheet.outsideKey,
                    leading: const Icon(Icons.person_add_alt_outlined),
                    title: Text(GuidanceStrings.outsideRoster(q)),
                    onTap: () => setState(() => _composing = true),
                  ),
                for (final p in candidates)
                  ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.memo == null ? p.role.label : '${p.role.label} · ${p.memo}'),
                    onTap: () => Navigator.pop(context, p.toParticipant()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _outsideForm() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_query.text.trim(), style: AppTextStyles.heading),
          const SizedBox(height: AppSizes.spacing12),
          Wrap(
            spacing: AppSizes.spacing8,
            children: [
              for (final r in PersonRole.values)
                ChoiceChip(
                  key: ParticipantPickerSheet.roleKey(r),
                  label: Text(r.label),
                  selected: _role == r,
                  onSelected: (_) => setState(() => _role = r),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          TextField(
            key: ParticipantPickerSheet.memoKey,
            controller: _memo,
            decoration: const InputDecoration(hintText: GuidanceStrings.outsideMemoHint),
          ),
          CheckboxListTile(
            key: ParticipantPickerSheet.addToRosterKey,
            contentPadding: EdgeInsets.zero,
            value: _addToRoster,
            onChanged: (v) => setState(() => _addToRoster = v ?? false),
            title: const Text(GuidanceStrings.addToRoster),
          ),
          const SizedBox(height: AppSizes.spacing8),
          FilledButton(
            key: ParticipantPickerSheet.confirmKey,
            onPressed: _busy ? null : _confirmOutside,
            child: const Text(GuidanceStrings.pickerConfirm),
          ),
        ],
      ),
    ),
  );
}
```

> 확인 버튼 색: `FilledButton` 기본은 `primary`(라이트에서 3.57:1 함정). `style: FilledButton.styleFrom(backgroundColor: AppColors.goldFill, foregroundColor: AppColors.onGold)`를 넣는다(import `app_colors.dart`).

Run: `flutter test test/features/guidance/presentation/participant_picker_sheet_test.dart`
Expected: PASS(4건).

- [ ] **Step 4: 사건 시각 입력을 만든다**

`lib/features/guidance/presentation/widgets/occurred_input.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/guidance_types.dart';

class OccurredValue {
  const OccurredValue({required this.precision, this.at, this.text});
  final OccurredPrecision precision;
  final DateTime? at;
  final String? text;
}

/// 사건 시각 — 정확히(날짜+시각) / 날짜만 / 대략(글). 날짜·시각 고르기는 탭의 중첩
/// 내비게이터에 띄운다(`useRootNavigator: false`, 가드).
class OccurredInput extends StatefulWidget {
  const OccurredInput({
    super.key,
    required this.precision,
    required this.onChanged,
    this.at,
    this.text,
  });

  final OccurredPrecision precision;
  final DateTime? at;
  final String? text;
  final ValueChanged<OccurredValue> onChanged;

  static Key precisionKey(OccurredPrecision p) => Key('occurred_${p.dbValue}');
  static const dateKey = Key('occurred_date');
  static const timeKey = Key('occurred_time');
  static const approxKey = Key('occurred_approx');

  @override
  State<OccurredInput> createState() => _OccurredInputState();
}

class _OccurredInputState extends State<OccurredInput> {
  late final _approx = TextEditingController(text: widget.text ?? '');

  @override
  void dispose() {
    _approx.dispose();
    super.dispose();
  }

  void _emit({OccurredPrecision? precision, DateTime? at, bool clearAt = false}) => widget.onChanged(
    OccurredValue(
      precision: precision ?? widget.precision,
      at: clearAt ? null : (at ?? widget.at),
      text: _approx.text,
    ),
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final base = widget.at ?? now;
    final d = await showDatePicker(
      context: context,
      useRootNavigator: false,
      initialDate: base,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (d == null) return;
    _emit(at: DateTime(d.year, d.month, d.day, base.hour, base.minute));
  }

  Future<void> _pickTime() async {
    final base = widget.at ?? DateTime.now();
    final t = await showTimePicker(
      context: context,
      useRootNavigator: false,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (t == null) return;
    _emit(at: DateTime(base.year, base.month, base.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final at = widget.at;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<OccurredPrecision>(
          showSelectedIcon: false,
          segments: [
            for (final p in OccurredPrecision.values)
              ButtonSegment(value: p, label: Text(p.label, key: OccurredInput.precisionKey(p))),
          ],
          selected: {widget.precision},
          onSelectionChanged: (s) {
            final p = s.first;
            // 대략으로 바꾸면 시각을 비운다 — 남겨 두면 저장할 때 정밀도와 어긋난다.
            _emit(precision: p, clearAt: p == OccurredPrecision.approx, at: at ?? DateTime.now());
          },
        ),
        const SizedBox(height: AppSizes.spacing8),
        if (widget.precision == OccurredPrecision.approx)
          TextField(
            key: OccurredInput.approxKey,
            controller: _approx,
            decoration: const InputDecoration(hintText: GuidanceStrings.approxHint),
            onChanged: (_) => _emit(),
          )
        else
          Wrap(
            spacing: AppSizes.spacing8,
            children: [
              OutlinedButton.icon(
                key: OccurredInput.dateKey,
                onPressed: _pickDate,
                icon: const Icon(Icons.event, size: AppSizes.iconSmall),
                label: Text(
                  at == null ? GuidanceStrings.pickDate : DateFormat('y. M. d. (E)', 'ko').format(at),
                ),
              ),
              if (widget.precision == OccurredPrecision.exact)
                OutlinedButton.icon(
                  key: OccurredInput.timeKey,
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: AppSizes.iconSmall),
                  label: Text(at == null ? GuidanceStrings.pickTime : DateFormat('HH:mm').format(at)),
                ),
            ],
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: 편집 화면 실패 테스트**

`test/features/guidance/presentation/guidance_edit_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_edit_screen.dart';
import 'package:planroutine/features/guidance/presentation/widgets/occurred_input.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// 편집 화면을 한 번 push한 상태로 띄운다 — 저장·취소가 pop하는지 보려고.
  Future<void> pump(WidgetTester tester, {int? recordId, double width = 390}) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRepositoryProvider.overrideWithValue(repo),
          guidancePeopleRepositoryProvider.overrideWithValue(GuidancePeopleRepository(dbHelper: db)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => GuidanceEditScreen(recordId: recordId)),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await settle(tester);
  }

  testWidgets('관련인·들은 말·판단·조치 안내 문구가 보인다', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.participantsHint), findsOneWidget);
    expect(find.text(GuidanceStrings.quotesHint), findsOneWidget);
    expect(find.text(GuidanceStrings.actionsHint), findsOneWidget);
    expect(find.text(GuidanceStrings.createdOnSave), findsOneWidget);
  });

  testWidgets('제목 없이 저장하면 막고 안내한다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    expect(find.text(GuidanceStrings.titleRequired), findsOneWidget);
    expect(await tester.runAsync(repo.getActive), isEmpty);
  });

  testWidgets('새 기록을 저장하면 판 1이 생기고 화면이 닫힌다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '복도 다툼');
    await tester.tap(find.byKey(GuidanceEditScreen.kindKey(GuidanceKind.infringement)));
    await tester.enterText(find.byKey(GuidanceEditScreen.factsKey), '밀침');
    await tester.enterText(find.byKey(GuidanceEditScreen.quotesKey), '"먼저 걸었어요"');
    await tester.enterText(find.byKey(GuidanceEditScreen.actionsKey), '분리 지도');
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    final list = await tester.runAsync(repo.getActive);
    final c = list?.single.content;
    expect(c?.title, '복도 다툼');
    expect(c?.kind, GuidanceKind.infringement);
    expect(c?.quotes, '"먼저 걸었어요"');
    expect(c?.actions, '분리 지도');
    expect(find.byType(GuidanceEditScreen), findsNothing);
  });

  testWidgets('고치기는 최신 판을 채워 열고, 저장하면 판 2가 된다', (tester) async {
    final id = await tester.runAsync(
      () => repo.create(const GuidanceContent(title: '처음', facts: '가')),
    );
    await pump(tester, recordId: id);
    expect(find.text('처음'), findsOneWidget);
    await tester.enterText(find.byKey(GuidanceEditScreen.factsKey), '가. 보건실 확인');
    await tester.tap(find.byKey(GuidanceEditScreen.statusKey(GuidanceStatus.closedAtSchool)));
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    final revs = await tester.runAsync(() => repo.getRevisions(id ?? -1));
    expect(revs?.map((r) => r.revisionNo), [2, 1]);
    expect(revs?.first.content.status, GuidanceStatus.closedAtSchool);
  });

  testWidgets('아무것도 안 고치고 저장하면 판을 만들지 않는다', (tester) async {
    final id = await tester.runAsync(() => repo.create(const GuidanceContent(title: '처음')));
    await pump(tester, recordId: id);
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    expect(await tester.runAsync(() => repo.getRevisions(id ?? -1)), hasLength(1));
  });

  testWidgets('대략을 고르면 글로 적고, 그대로 저장된다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '반복된 놀림');
    await tester.tap(find.byKey(OccurredInput.precisionKey(OccurredPrecision.approx)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(OccurredInput.approxKey), '3월 초~여름방학 전');
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    final c = (await tester.runAsync(repo.getActive))?.single.content;
    expect(c?.precision, OccurredPrecision.approx);
    expect(c?.occurredText, '3월 초~여름방학 전');
    expect(c?.occurredAt, isNull);
  });

  testWidgets('고친 내용이 있으면 취소할 때 묻고, 그대로 두기를 고르면 남는다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '쓰던 것');
    await tester.tap(find.byKey(GuidanceEditScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.discardTitle), findsOneWidget);
    // 앱바의 `취소`와 대화상자의 `취소`가 같은 글이라 마지막(대화상자) 것을 누른다
    await tester.tap(find.text(AppStrings.cancel).last);
    await tester.pumpAndSettle();
    expect(find.byType(GuidanceEditScreen), findsOneWidget);
    await tester.tap(find.byKey(GuidanceEditScreen.cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(GuidanceStrings.discardConfirm));
    await tester.pumpAndSettle();
    expect(find.byType(GuidanceEditScreen), findsNothing);
  });

  testWidgets('320pt에서 넘치지 않는다', (tester) async {
    await pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });
}
```

Run: `flutter test test/features/guidance/presentation/guidance_edit_screen_test.dart`
Expected: FAIL — 화면 없음.

- [ ] **Step 6: 편집 화면을 구현한다**

`lib/features/guidance/presentation/screens/guidance_edit_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../domain/guidance_content.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';
import '../providers/guidance_providers.dart';
import '../widgets/occurred_input.dart';
import '../widgets/participant_picker_sheet.dart';

/// 새 기록·고치기 공용 전체 화면. 저장은 판을 하나 더한다(같은 내용이면 더하지 않는다).
class GuidanceEditScreen extends ConsumerStatefulWidget {
  const GuidanceEditScreen({super.key, this.recordId});

  final int? recordId;

  static const saveKey = Key('guidance_edit_save');
  static const cancelKey = Key('guidance_edit_cancel');
  static const titleKey = Key('guidance_edit_title');
  static const placeKey = Key('guidance_edit_place');
  static const factsKey = Key('guidance_edit_facts');
  static const quotesKey = Key('guidance_edit_quotes');
  static const actionsKey = Key('guidance_edit_actions');
  static const addPersonKey = Key('guidance_edit_add_person');
  static Key kindKey(GuidanceKind k) => Key('guidance_edit_kind_${k.dbValue}');
  static Key statusKey(GuidanceStatus s) => Key('guidance_edit_status_${s.dbValue}');

  @override
  ConsumerState<GuidanceEditScreen> createState() => _GuidanceEditScreenState();
}

class _GuidanceEditScreenState extends ConsumerState<GuidanceEditScreen> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _facts = TextEditingController();
  final _quotes = TextEditingController();
  final _actions = TextEditingController();

  var _kind = GuidanceKind.guidance;
  var _status = GuidanceStatus.open;
  var _precision = OccurredPrecision.exact;
  DateTime? _occurredAt = DateTime.now();
  String? _occurredText;
  var _participants = <Participant>[];

  /// 고치는 중인 기록 id. 새 기록이면 null이었다가 처음 저장(또는 Task 8의 첨부)에서 정해진다.
  int? _recordId;

  /// 마지막으로 DB에 들어간 내용. 이것과 다르면 "고친 내용이 있다".
  GuidanceContent? _saved;
  String? _createdAt;
  var _loaded = false;
  var _titleError = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _recordId = widget.recordId;
    for (final c in [_title, _place, _facts, _quotes, _actions]) {
      c.addListener(_touch);
    }
    _load();
  }

  void _touch() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final id = widget.recordId;
    if (id == null) {
      _saved = _current();
      setState(() => _loaded = true);
      return;
    }
    final record = await ref.read(guidanceRepositoryProvider).getRecord(id);
    if (!mounted || record == null) return;
    final c = record.content;
    _title.text = c.title;
    _place.text = c.place ?? '';
    _facts.text = c.facts ?? '';
    _quotes.text = c.quotes ?? '';
    _actions.text = c.actions ?? '';
    setState(() {
      _kind = c.kind;
      _status = c.status;
      _precision = c.precision;
      _occurredAt = c.occurredAt;
      _occurredText = c.occurredText;
      _participants = [...c.participants];
      _createdAt = record.createdAt;
      _saved = c.normalized();
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _place, _facts, _quotes, _actions]) {
      c.dispose();
    }
    super.dispose();
  }

  GuidanceContent _current() => GuidanceContent(
    kind: _kind,
    status: _status,
    precision: _precision,
    occurredAt: _occurredAt,
    occurredText: _occurredText,
    title: _title.text,
    place: _place.text,
    participants: _participants,
    facts: _facts.text,
    quotes: _quotes.text,
    actions: _actions.text,
  ).normalized();

  bool get _dirty {
    final saved = _saved;
    return _loaded && saved != null && !sameContent(saved, _current());
  }

  /// 아직 DB에 없는 새 기록을 지금 만든다 — 제목이 비었으면 `제목 없음`으로.
  /// Task 8(첨부)이 쓴다: 녹음·사진을 붙이는 순간 기록이 저장돼 있어야 한다.
  Future<int> _ensureRecord() async {
    final existing = _recordId;
    if (existing != null) return existing;
    var content = _current();
    if (content.title.isEmpty) content = content.copyWith(title: GuidanceStrings.untitled);
    final id = await ref.read(guidanceActionsProvider).create(content);
    final record = await ref.read(guidanceRepositoryProvider).getRecord(id);
    if (mounted) {
      setState(() {
        _recordId = id;
        _saved = content;
        _createdAt = record?.createdAt;
      });
    }
    return id;
  }

  Future<void> _save() async {
    if (_busy) return;
    final content = _current();
    if (content.title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    setState(() => _busy = true);
    final actions = ref.read(guidanceActionsProvider);
    final id = _recordId;
    if (id == null) {
      _recordId = await actions.create(content);
    } else {
      await actions.save(id, content);
    }
    _saved = content;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmLeave() async {
    final leave = await ConfirmDialog.show(
      context: context,
      useRootNavigator: false,
      title: GuidanceStrings.discardTitle,
      message: GuidanceStrings.discardMessage,
      confirmLabel: GuidanceStrings.discardConfirm,
    );
    if (leave && mounted) {
      _saved = _current();
      setState(() {});
      Navigator.of(context).pop();
    }
  }

  Future<void> _addPerson() async {
    final p = await showParticipantPicker(context, exclude: _participants);
    if (p == null || !mounted) return;
    setState(() => _participants = [..._participants, p]);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final created = _createdAt;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 72,
          leading: TextButton(
            key: GuidanceEditScreen.cancelKey,
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text(GuidanceStrings.cancel),
          ),
          title: Text(
            widget.recordId == null ? GuidanceStrings.editNewTitle : GuidanceStrings.editTitle,
            style: AppTextStyles.heading,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.spacing8),
              child: FilledButton(
                key: GuidanceEditScreen.saveKey,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.goldFill,
                  foregroundColor: AppColors.onGold,
                ),
                onPressed: _busy ? null : _save,
                child: const Text(GuidanceStrings.save),
              ),
            ),
          ],
        ),
        body: !_loaded
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.spacing16, AppSizes.spacing16, AppSizes.spacing16, AppSizes.spacing48,
                ),
                children: [
                  _label(GuidanceStrings.labelKind),
                  SegmentedButton<GuidanceKind>(
                    showSelectedIcon: false,
                    segments: [
                      for (final k in GuidanceKind.values)
                        ButtonSegment(
                          value: k,
                          label: Text(k.label, key: GuidanceEditScreen.kindKey(k)),
                        ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (s) => setState(() => _kind = s.first),
                  ),
                  _gap(),
                  _label(GuidanceStrings.labelStatus),
                  SegmentedButton<GuidanceStatus>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: GuidanceStatus.open,
                        label: Text(GuidanceStrings.statusOpen,
                            key: GuidanceEditScreen.statusKey(GuidanceStatus.open)),
                      ),
                      ButtonSegment(
                        value: GuidanceStatus.closedAtSchool,
                        label: Text(GuidanceStrings.statusClosedShort,
                            key: GuidanceEditScreen.statusKey(GuidanceStatus.closedAtSchool)),
                      ),
                      ButtonSegment(
                        value: GuidanceStatus.transferred,
                        label: Text(GuidanceStrings.statusTransferredShort,
                            key: GuidanceEditScreen.statusKey(GuidanceStatus.transferred)),
                      ),
                    ],
                    selected: {_status},
                    onSelectionChanged: (s) => setState(() => _status = s.first),
                  ),
                  _gap(),
                  _label(GuidanceStrings.labelOccurred),
                  OccurredInput(
                    precision: _precision,
                    at: _occurredAt,
                    text: _occurredText,
                    onChanged: (v) => setState(() {
                      _precision = v.precision;
                      _occurredAt = v.at;
                      _occurredText = v.text;
                    }),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  Text(
                    '${GuidanceStrings.labelCreated} · '
                    '${created == null ? GuidanceStrings.createdOnSave : formatStamp(created, now: now)}',
                    style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
                  ),
                  _gap(),
                  _label(GuidanceStrings.labelTitle),
                  TextField(
                    key: GuidanceEditScreen.titleKey,
                    controller: _title,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      errorText: _titleError && _title.text.trim().isEmpty
                          ? GuidanceStrings.titleRequired
                          : null,
                    ),
                  ),
                  _gap(),
                  _label(GuidanceStrings.labelPlace),
                  TextField(key: GuidanceEditScreen.placeKey, controller: _place),
                  _gap(),
                  _label(GuidanceStrings.labelParticipants),
                  Wrap(
                    spacing: AppSizes.spacing8,
                    runSpacing: AppSizes.spacing8,
                    children: [
                      for (final p in _participants)
                        InputChip(
                          label: Text(p.displayName),
                          onDeleted: () => setState(
                            () => _participants = [
                              for (final q in _participants)
                                if (!identical(q, p)) q,
                            ],
                          ),
                        ),
                      ActionChip(
                        key: GuidanceEditScreen.addPersonKey,
                        avatar: const Icon(Icons.add, size: AppSizes.iconSmall),
                        label: const Text(GuidanceStrings.addPerson),
                        onPressed: _addPerson,
                      ),
                    ],
                  ),
                  _hint(GuidanceStrings.participantsHint),
                  _gap(),
                  _label(GuidanceStrings.labelFacts),
                  TextField(
                    key: GuidanceEditScreen.factsKey,
                    controller: _facts,
                    minLines: 5,
                    maxLines: null,
                  ),
                  _gap(),
                  _label(GuidanceStrings.labelQuotes),
                  TextField(
                    key: GuidanceEditScreen.quotesKey,
                    controller: _quotes,
                    minLines: 3,
                    maxLines: null,
                  ),
                  _hint(GuidanceStrings.quotesHint),
                  _gap(),
                  _label(GuidanceStrings.labelActions),
                  TextField(
                    key: GuidanceEditScreen.actionsKey,
                    controller: _actions,
                    minLines: 3,
                    maxLines: null,
                  ),
                  _hint(GuidanceStrings.actionsHint),
                ],
              ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: AppSizes.spacing20);

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
    child: Text(text, style: AppTextStyles.label.copyWith(color: AppColors.sub)),
  );

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSizes.spacing8),
    child: Text(text, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
  );
}
```

> `_ensureRecord`는 이 Task에서 쓰는 곳이 없어 analyze가 `unused_element`를 낸다. 그 줄 위에 `// ignore: unused_element — Task 8(첨부)이 쓴다`를 붙이고, Task 8에서 이 주석을 지운다.

- [ ] **Step 7: 라우트를 더한다**

`app_router.dart`의 지도 기록 `GoRoute(path: AppRoutes.guidance, ...)`에서 `routes: const []`를 아래로 바꾼다(import `guidance_edit_screen.dart`):

```dart
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const GuidanceEditScreen(),
                ),
                GoRoute(
                  path: 'record/:id/edit',
                  builder: (context, state) => GuidanceEditScreen(
                    recordId: int.tryParse(state.pathParameters['id'] ?? ''),
                  ),
                ),
              ],
```

> Task 7이 `record/:id`(보기)를 더하면서 `edit`를 그 하위로 옮긴다.

- [ ] **Step 8: 통과를 확인한다**

Run: `flutter test test/features/guidance/ && flutter analyze`
Expected: 전부 PASS, `No issues found!`(루트 내비게이터 가드도 `showDatePicker`·`showTimePicker`·`ConfirmDialog.show`를 검사해 통과해야 한다).

- [ ] **Step 9: 커밋**

```bash
git add lib/features/guidance lib/core/router/app_router.dart lib/core/constants/strings/guidance_strings.dart test/features/guidance
git commit -m "feat(guidance): 기록 쓰기·고치기 — 사건 시각 3종·관련인 고르기·판단·조치 칸

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017CsGY18wT1wE3iKefCxJo7"
```

---

### Task 7: 기록 보기 · 수정 이력 · 첨부 표시(재생·사진·해시)

**Files:**
- Modify: `pubspec.yaml` (`just_audio: ^0.10.6`)
- Create: `lib/features/guidance/presentation/screens/guidance_detail_screen.dart`, `lib/features/guidance/presentation/screens/guidance_history_screen.dart`, `lib/features/guidance/presentation/widgets/audio_playback.dart`, `lib/features/guidance/presentation/widgets/attachment_tile.dart`, `lib/features/guidance/presentation/widgets/attachment_info_sheet.dart`
- Modify: `lib/core/router/app_router.dart`, `lib/core/constants/strings/guidance_strings.dart`
- Test: `test/features/guidance/presentation/guidance_detail_screen_test.dart`, `test/features/guidance/presentation/guidance_history_screen_test.dart`, `test/features/guidance/presentation/attachment_tile_test.dart`

**Interfaces:**
- Consumes: Task 4 provider·`GuidanceActions.delete`, Task 3 `GuidanceFileStore.fileOf`, Task 6 `GuidanceEditScreen`.
- Produces:
  - `abstract class AudioPlayback { Future<void> play(String path); Future<void> pause(); Stream<Duration> get position; Stream<bool> get playing; Future<void> dispose(); }`, `audioPlaybackFactoryProvider` (`Provider<AudioPlayback Function()>`)
  - `AttachmentTile({required GuidanceAttachment attachment, required DateTime now, VoidCallback? onRemove})` — 키 `playKey(int id)`, `infoKey(int id)`, `removeKey(int id)`, `imageKey(int id)`
  - `showAttachmentInfo(BuildContext, GuidanceAttachment, {required DateTime now})`
  - `GuidanceDetailScreen({required int recordId})` — 키 `editKey`, `menuKey`, `deleteKey`, `historyKey`
  - `GuidanceHistoryScreen({required int recordId})` — 키 `revisionKey(int no)`
- 라우트: `record/:id` → 보기, 그 하위 `edit`·`history`

- [ ] **Step 1: 의존성과 문자열**

Run: `flutter pub add just_audio:^0.10.6`

```dart
  // 기록 보기
  static const edit = '고치기';
  static const delete = '삭제';
  static const more = '더 보기';
  static const labelOccurredShort = '사건';
  static const labelCreatedShort = '기록';
  static String revisionLink(int times, String last) => '수정 $times회 · 마지막 $last';
  static const labelAttachments = '첨부';
  static const deleteTitle = '이 기록을 삭제할까요?';
  static const deleteMessage = '삭제한 기록으로 옮겨집니다. 자동으로 지워지지 않으며, 거기서 되살릴 수 있습니다.';
  static const outsideRosterBadge = '명단 밖';

  // 첨부
  static const play = '재생';
  static const pause = '멈춤';
  static const attachmentInfo = '첨부 정보';
  static const removeAttachment = '첨부에서 빼기';
  static const infoSource = '출처';
  static const infoOriginalName = '원래 이름';
  static const infoSize = '크기';
  static const infoCaptured = '녹음 시작';
  static const infoAttached = '붙인 시각';
  static const infoHash = 'SHA-256';
  static const infoHashNote = '파일이 바뀌지 않았음을 확인할 때 쓰는 값입니다.';
  static String durationLabel(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  static String sizeLabel(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB'
      : '${(bytes / 1024).ceil()}KB';

  // 수정 이력
  static const historyTitle = '수정 이력';
  static const historyIntro = '저장할 때마다 그때의 내용이 그대로 남습니다. 이전 판은 고치거나 지울 수 없어요.';
  static String revisionTitle(int no) => '판 $no';
  static const revisionCurrent = '현재';
  static const revisionFirst = '처음 기록';
  static String changedLabel(String fields) => '바뀐 칸: $fields';
  static const attachmentLog = '첨부 기록';
  static String attachedLog(String what) => '$what 붙임';
  static String removedLog(String what) => '$what 뺌';
```

- [ ] **Step 2: 재생 래퍼를 만든다**

`lib/features/guidance/presentation/widgets/audio_playback.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// 녹음 재생. 위젯 테스트에서 플랫폼 플러그인을 부르지 않으려고 인터페이스로 둔다.
abstract class AudioPlayback {
  Future<void> play(String path);
  Future<void> pause();
  Stream<Duration> get position;
  Stream<bool> get playing;
  Future<void> dispose();
}

class JustAudioPlayback implements AudioPlayback {
  final _player = AudioPlayer();
  String? _loaded;

  @override
  Future<void> play(String path) async {
    if (_loaded != path) {
      await _player.setFilePath(path);
      _loaded = path;
    }
    // play()는 끝날 때까지 기다리는 Future라 await하지 않는다.
    _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<bool> get playing => _player.playingStream;

  @override
  Future<void> dispose() => _player.dispose();
}

/// 첨부마다 플레이어를 하나씩 만든다.
final audioPlaybackFactoryProvider = Provider<AudioPlayback Function()>(
  (ref) => JustAudioPlayback.new,
);
```

- [ ] **Step 3: 첨부 타일 실패 테스트**

`test/features/guidance/presentation/attachment_tile_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/widgets/attachment_tile.dart';
import 'package:planroutine/features/guidance/presentation/widgets/audio_playback.dart';

class FakePlayback implements AudioPlayback {
  final played = <String>[];
  final _playing = StreamController<bool>.broadcast();
  @override
  Future<void> play(String path) async {
    played.add(path);
    _playing.add(true);
  }

  @override
  Future<void> pause() async => _playing.add(false);
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Future<void> dispose() async => _playing.close();
}

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  late Directory base;
  late FakePlayback playback;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('att_tile');
    playback = FakePlayback();
  });
  tearDown(() async => base.delete(recursive: true));

  const audio = GuidanceAttachment(
    id: 1,
    recordId: 1,
    type: AttachmentType.audio,
    source: AttachmentSource.recorded,
    fileName: 'r.m4a',
    sha256: 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    byteSize: 2048,
    durationMs: 768000,
    capturedAt: '2026-10-02T15:41:00.000',
    attachedAt: '2026-10-02T15:54:00.000',
  );

  Future<void> pump(WidgetTester tester, GuidanceAttachment a, {VoidCallback? onRemove}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceFileStoreProvider.overrideWithValue(GuidanceFileStore(baseDir: () async => base)),
          audioPlaybackFactoryProvider.overrideWithValue(() => playback),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AttachmentTile(attachment: a, now: DateTime(2026, 10, 3), onRemove: onRemove),
          ),
        ),
      ),
    );
    // 파일 위치를 찾는 I/O(폴더 만들기)는 fake-async 밖에서 끝나야 한다
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  testWidgets('녹음은 길이·출처를 보여 주고 누르면 그 파일을 재생한다', (tester) async {
    await pump(tester, audio);
    expect(find.textContaining('12:48'), findsOneWidget);
    expect(find.textContaining(GuidanceStrings.sourceRecorded), findsOneWidget);
    await tester.tap(find.byKey(AttachmentTile.playKey(1)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(playback.played.single.endsWith('r.m4a'), isTrue);
  });

  testWidgets('정보를 누르면 해시와 원래 이름이 보인다', (tester) async {
    await pump(tester, audio.copyWith(source: AttachmentSource.imported, originalName: '통화 녹음 1002.m4a'));
    await tester.tap(find.byKey(AttachmentTile.infoKey(1)));
    await tester.pumpAndSettle();
    expect(find.text(audio.sha256), findsOneWidget);
    expect(find.text('통화 녹음 1002.m4a'), findsOneWidget);
  });

  testWidgets('빼기 버튼은 onRemove가 있을 때만 보인다', (tester) async {
    await pump(tester, audio);
    expect(find.byKey(AttachmentTile.removeKey(1)), findsNothing);
    var removed = false;
    await pump(tester, audio, onRemove: () => removed = true);
    await tester.tap(find.byKey(AttachmentTile.removeKey(1)));
    expect(removed, isTrue);
  });
}
```

Run: `flutter test test/features/guidance/presentation/attachment_tile_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 4: 첨부 타일·정보 시트를 구현한다**

`lib/features/guidance/presentation/widgets/attachment_info_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';

Future<void> showAttachmentInfo(
  BuildContext context,
  GuidanceAttachment a, {
  required DateTime now,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.spacing20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(GuidanceStrings.attachmentInfo, style: AppTextStyles.heading),
          const SizedBox(height: AppSizes.spacing12),
          _row(GuidanceStrings.infoSource, '${a.type.label} · ${a.source.label}'),
          if (a.originalName case final name?) _row(GuidanceStrings.infoOriginalName, name),
          _row(GuidanceStrings.infoSize, GuidanceStrings.sizeLabel(a.byteSize)),
          if (a.capturedAt case final at?) _row(GuidanceStrings.infoCaptured, formatStamp(at, now: now)),
          _row(GuidanceStrings.infoAttached, formatStamp(a.attachedAt, now: now)),
          const SizedBox(height: AppSizes.spacing8),
          Text(GuidanceStrings.infoHash, style: AppTextStyles.label.copyWith(color: AppColors.sub)),
          SelectableText(a.sha256, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          const SizedBox(height: AppSizes.spacing4),
          Text(GuidanceStrings.infoHashNote, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
        ],
      ),
    ),
  ),
);

Widget _row(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 80, child: Text(label, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub))),
      Expanded(child: Text(value, style: AppTextStyles.bodyM)),
    ],
  ),
);
```

`lib/features/guidance/presentation/widgets/attachment_tile.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../providers/guidance_providers.dart';
import 'attachment_info_sheet.dart';
import 'audio_playback.dart';

/// 첨부 한 줄. 녹음은 재생/멈춤, 사진은 썸네일(누르면 전체 화면). ⓘ로 해시·원래 이름을 본다.
class AttachmentTile extends ConsumerStatefulWidget {
  const AttachmentTile({super.key, required this.attachment, required this.now, this.onRemove});

  final GuidanceAttachment attachment;
  final DateTime now;
  final VoidCallback? onRemove;

  static Key playKey(int id) => Key('att_play_$id');
  static Key infoKey(int id) => Key('att_info_$id');
  static Key removeKey(int id) => Key('att_remove_$id');
  static Key imageKey(int id) => Key('att_image_$id');

  @override
  ConsumerState<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends ConsumerState<AttachmentTile> {
  AudioPlayback? _player;
  StreamSubscription<bool>? _sub;
  var _playing = false;
  File? _file;

  @override
  void initState() {
    super.initState();
    ref.read(guidanceFileStoreProvider).fileOf(widget.attachment.fileName).then((f) {
      if (mounted) setState(() => _file = f);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final file = _file;
    if (file == null) return;
    final player = _player ?? ref.read(audioPlaybackFactoryProvider)();
    if (_player == null) {
      _player = player;
      _sub = player.playing.listen((p) {
        if (mounted) setState(() => _playing = p);
      });
    }
    if (_playing) {
      await player.pause();
    } else {
      await player.play(file.path);
    }
  }

  void _openImage(File file) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(child: InteractiveViewer(child: Image.file(file))),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    final id = a.id ?? -1;
    final file = _file;
    final subtitle = a.type == AttachmentType.audio && a.durationMs != null
        ? '${a.source.label} · ${GuidanceStrings.durationLabel(a.durationMs ?? 0)}'
        : '${a.source.label} · ${GuidanceStrings.sizeLabel(a.byteSize)}';
    final leading = a.type == AttachmentType.audio
        ? IconButton.filled(
            key: AttachmentTile.playKey(id),
            tooltip: _playing ? GuidanceStrings.pause : GuidanceStrings.play,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
            ),
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          )
        : InkWell(
            key: AttachmentTile.imageKey(id),
            onTap: file == null ? null : () => _openImage(file),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: file == null
                    ? ColoredBox(color: AppColors.surfaceVariant)
                    : Image.file(file, fit: BoxFit.cover, cacheWidth: 144),
              ),
            ),
          );
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing8),
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.originalName ?? a.type.label, style: AppTextStyles.bodyM, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
                ],
              ),
            ),
            IconButton(
              key: AttachmentTile.infoKey(id),
              tooltip: GuidanceStrings.attachmentInfo,
              icon: const Icon(Icons.info_outline),
              onPressed: () => showAttachmentInfo(context, a, now: widget.now),
            ),
            if (widget.onRemove != null)
              IconButton(
                key: AttachmentTile.removeKey(id),
                tooltip: GuidanceStrings.removeAttachment,
                icon: const Icon(Icons.close),
                onPressed: widget.onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
```

Run: `flutter test test/features/guidance/presentation/attachment_tile_test.dart`
Expected: PASS

- [ ] **Step 5: 보기·이력 실패 테스트**

`test/features/guidance/presentation/guidance_detail_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_detail_screen.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, int id) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => GuidanceDetailScreen(recordId: id)),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await settle(tester);
  }

  testWidgets('사건 시각과 기록 시각, 칸 셋, 명단 밖 표시를 보여 준다', (tester) async {
    final id = await tester.runAsync(
      () => repo.create(
        GuidanceContent(
          title: '복도 다툼',
          occurredAt: DateTime(2026, 10, 2, 15, 30),
          participants: const [Participant(personId: 1, name: '김하늘'), Participant(name: '박서준', memo: '5반')],
          facts: '밀침',
          quotes: '"먼저 걸었어요"',
          actions: '분리 지도',
        ),
      ),
    );
    await pump(tester, id ?? -1);
    expect(find.text('복도 다툼'), findsOneWidget);
    expect(find.textContaining('15:30'), findsOneWidget);
    expect(find.text(GuidanceStrings.labelCreatedShort), findsOneWidget);
    expect(find.text('밀침'), findsOneWidget);
    expect(find.text('"먼저 걸었어요"'), findsOneWidget);
    expect(find.text('분리 지도'), findsOneWidget);
    expect(find.textContaining(GuidanceStrings.outsideRosterBadge), findsOneWidget);
    // 판이 하나면 수정 링크가 없다
    expect(find.byKey(GuidanceDetailScreen.historyKey), findsNothing);
  });

  testWidgets('고친 기록에는 수정 링크가 보인다', (tester) async {
    final id = await tester.runAsync(() async {
      final id = await repo.create(const GuidanceContent(title: 't'));
      await repo.saveRevision(id, const GuidanceContent(title: 't', facts: '덧붙임'));
      return id;
    });
    await pump(tester, id ?? -1);
    expect(find.byKey(GuidanceDetailScreen.historyKey), findsOneWidget);
    expect(find.textContaining('수정 1회'), findsOneWidget);
  });

  testWidgets('삭제는 묻고, 확인하면 삭제한 기록으로 가고 화면이 닫힌다', (tester) async {
    final id = await tester.runAsync(() => repo.create(const GuidanceContent(title: '지울 것')));
    await pump(tester, id ?? -1);
    await tester.tap(find.byKey(GuidanceDetailScreen.menuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GuidanceDetailScreen.deleteKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.deleteTitle), findsOneWidget);
    await tester.tap(find.text(GuidanceStrings.delete).last);
    await settle(tester);
    expect(await tester.runAsync(repo.getActive), isEmpty);
    expect((await tester.runAsync(repo.getDeleted))?.single.id, id);
    expect(find.byType(GuidanceDetailScreen), findsNothing);
  });

  testWidgets('이관 상태는 배지로 보인다', (tester) async {
    final id = await tester.runAsync(
      () => repo.create(const GuidanceContent(title: 't', status: GuidanceStatus.transferred)),
    );
    await pump(tester, id ?? -1);
    expect(find.text(GuidanceStrings.statusTransferredShort), findsOneWidget);
  });
}
```

`test/features/guidance/presentation/guidance_history_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_history_screen.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  testWidgets('판마다 저장 시각·전체 내용을 보여 주고 바뀐 칸을 말한다', (tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final id = await tester.runAsync(() async {
      final id = await repo.create(const GuidanceContent(title: '복도 다툼', facts: '처음 쓴 경과'));
      await repo.saveRevision(
        id,
        const GuidanceContent(title: '복도 다툼', facts: '고친 경과', status: GuidanceStatus.closedAtSchool),
      );
      final a = await repo.addAttachment(
        GuidanceAttachment(
          recordId: id,
          type: AttachmentType.audio,
          source: AttachmentSource.imported,
          fileName: 'x.m4a',
          originalName: '음성 메모 0930.m4a',
          sha256: 'h',
          byteSize: 1,
          attachedAt: DateTime(2026, 10, 2, 17, 10).toIso8601String(),
        ),
      );
      await repo.removeAttachment(a.id ?? -1);
      return id;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: GuidanceHistoryScreen(recordId: id ?? -1)),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text(GuidanceStrings.historyIntro), findsOneWidget);
    expect(find.byKey(GuidanceHistoryScreen.revisionKey(2)), findsOneWidget);
    expect(find.byKey(GuidanceHistoryScreen.revisionKey(1)), findsOneWidget);
    expect(find.text('처음 쓴 경과'), findsOneWidget, reason: '옛 판의 원문이 남아 있다');
    expect(find.text('고친 경과'), findsOneWidget);
    expect(find.text(GuidanceStrings.revisionCurrent), findsOneWidget);
    expect(find.text(GuidanceStrings.revisionFirst), findsOneWidget);
    expect(
      find.text(GuidanceStrings.changedLabel('${GuidanceStrings.fieldStatus}, ${GuidanceStrings.fieldFacts}')),
      findsOneWidget,
    );
    expect(find.textContaining(GuidanceStrings.attachedLog('음성 메모 0930.m4a')), findsOneWidget);
    expect(find.textContaining(GuidanceStrings.removedLog('음성 메모 0930.m4a')), findsOneWidget);
  });
}
```

Run: `flutter test test/features/guidance/presentation/guidance_detail_screen_test.dart test/features/guidance/presentation/guidance_history_screen_test.dart`
Expected: FAIL — 화면 없음.

- [ ] **Step 6: 기록 보기를 구현한다**

`lib/features/guidance/presentation/screens/guidance_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';
import '../providers/guidance_providers.dart';
import '../widgets/attachment_tile.dart';
import '../widgets/guidance_badges.dart';

class GuidanceDetailScreen extends ConsumerWidget {
  const GuidanceDetailScreen({super.key, required this.recordId});

  final int recordId;

  static const editKey = Key('guidance_detail_edit');
  static const menuKey = Key('guidance_detail_menu');
  static const deleteKey = Key('guidance_detail_delete');
  static const historyKey = Key('guidance_detail_history');

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await ConfirmDialog.show(
      context: context,
      useRootNavigator: false,
      title: GuidanceStrings.deleteTitle,
      message: GuidanceStrings.deleteMessage,
      confirmLabel: GuidanceStrings.delete,
      confirmColor: AppColors.error,
    );
    if (!ok) return;
    await ref.read(guidanceActionsProvider).delete(recordId);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(guidanceRecordProvider(recordId)).valueOrNull;
    final attachments = [
      for (final a in ref.watch(guidanceAttachmentsProvider(recordId)).valueOrNull ?? const <GuidanceAttachment>[])
        if (!a.isRemoved) a,
    ];
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            key: editKey,
            onPressed: () => context.push(AppRoutes.guidanceEdit(recordId)),
            child: const Text(GuidanceStrings.edit),
          ),
          PopupMenuButton<String>(
            key: menuKey,
            tooltip: GuidanceStrings.more,
            onSelected: (_) => _delete(context, ref),
            itemBuilder: (_) => const [
              PopupMenuItem(key: deleteKey, value: 'delete', child: Text(GuidanceStrings.delete)),
            ],
          ),
        ],
      ),
      body: record == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding, 0, AppSizes.pagePadding, AppSizes.spacing48,
              ),
              children: [
                Row(
                  children: [
                    GuidanceKindBadge(record.content.kind),
                    if (record.content.status != GuidanceStatus.open) ...[
                      const SizedBox(width: AppSizes.spacing4),
                      GuidanceStatusBadge(record.content.status),
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.spacing8),
                Text(record.content.title, style: AppTextStyles.titleM),
                const SizedBox(height: AppSizes.spacing8),
                _meta(GuidanceStrings.labelOccurredShort, _occurredLine(record, now)),
                _meta(GuidanceStrings.labelCreatedShort, formatStamp(record.createdAt, now: now)),
                if (record.revisionCount > 1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: historyKey,
                      onPressed: () => context.push(AppRoutes.guidanceHistory(recordId)),
                      icon: const Icon(Icons.history, size: AppSizes.iconSmall),
                      label: Text(
                        GuidanceStrings.revisionLink(
                          record.revisionCount - 1,
                          formatStamp(record.latest.savedAt, now: now),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSizes.spacing12),
                if (record.content.participants.isNotEmpty)
                  Wrap(
                    spacing: AppSizes.spacing8,
                    runSpacing: AppSizes.spacing8,
                    children: [for (final p in record.content.participants) _personChip(p)],
                  ),
                _section(GuidanceStrings.labelFacts, record.content.facts),
                _section(GuidanceStrings.labelQuotes, record.content.quotes, boxed: true),
                _section(GuidanceStrings.labelActions, record.content.actions),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.spacing20),
                  _heading(GuidanceStrings.labelAttachments),
                  for (final a in attachments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
                      child: AttachmentTile(attachment: a, now: now),
                    ),
                ],
              ],
            ),
    );
  }

  String _occurredLine(GuidanceRecord r, DateTime now) {
    final place = r.content.place;
    final when = formatOccurred(r.content, now: now);
    return place == null ? when : '$when · $place';
  }

  Widget _meta(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.spacing4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 48, child: Text(label, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub))),
        Expanded(child: Text(value, style: AppTextStyles.bodyS)),
      ],
    ),
  );

  /// 명단 사람은 채운 칩, 명단 밖은 테두리 칩 + `명단 밖` — 색만이 아니라 형태와 글로 구분한다.
  Widget _personChip(Participant p) => p.personId != null
      ? Chip(label: Text(p.displayName), backgroundColor: AppColors.surfaceVariant, side: BorderSide.none)
      : Chip(
          label: Text('${p.displayName} · ${GuidanceStrings.outsideRosterBadge}'),
          backgroundColor: Colors.transparent,
          side: BorderSide(color: AppColors.lineStrong),
        );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
    child: Text(text, style: AppTextStyles.label.copyWith(color: AppColors.sub)),
  );

  Widget _section(String label, String? body, {bool boxed = false}) {
    if (body == null) return const SizedBox.shrink();
    final text = Text(body, style: AppTextStyles.bodyL);
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(label),
          if (boxed)
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSizes.radius12),
              ),
              child: Padding(padding: const EdgeInsets.all(AppSizes.spacing12), child: text),
            )
          else
            text,
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: 수정 이력을 구현한다**

`lib/features/guidance/presentation/screens/guidance_history_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../providers/guidance_providers.dart';

/// 판 목록(최신 위). 각 판은 그때의 **전체 내용**을 보여 주고, 앞 판과 견주어 바뀐 칸을 말한다.
class GuidanceHistoryScreen extends ConsumerWidget {
  const GuidanceHistoryScreen({super.key, required this.recordId});

  final int recordId;

  static Key revisionKey(int no) => Key('guidance_revision_$no');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revs = ref.watch(guidanceRevisionsProvider(recordId)).valueOrNull ?? const <GuidanceRevision>[];
    final atts = ref.watch(guidanceAttachmentsProvider(recordId)).valueOrNull ?? const <GuidanceAttachment>[];
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(GuidanceStrings.historyTitle, style: AppTextStyles.heading)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSizes.spacing16, 0, AppSizes.spacing16, AppSizes.spacing48),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spacing12),
            child: Text(GuidanceStrings.historyIntro, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
          ),
          for (final (i, r) in revs.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spacing12),
              child: _RevisionCard(
                key: revisionKey(r.revisionNo),
                revision: r,
                previous: i + 1 < revs.length ? revs[i + 1] : null,
                isCurrent: i == 0,
                now: now,
              ),
            ),
          if (atts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.spacing8, bottom: AppSizes.spacing8),
              child: Text(GuidanceStrings.attachmentLog, style: AppTextStyles.label.copyWith(color: AppColors.sub)),
            ),
            for (final a in atts) ...[
              _logLine(GuidanceStrings.attachedLog(_what(a)), formatStamp(a.attachedAt, now: now)),
              if (a.removedAt case final removed?)
                _logLine(GuidanceStrings.removedLog(_what(a)), formatStamp(removed, now: now)),
            ],
          ],
        ],
      ),
    );
  }

  String _what(GuidanceAttachment a) => a.originalName ?? '${a.type.label}(${a.source.label})';

  Widget _logLine(String text, String when) => Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.spacing4),
    child: Row(
      children: [
        Expanded(child: Text(text, style: AppTextStyles.bodyS)),
        Text(when, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
      ],
    ),
  );
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({
    super.key,
    required this.revision,
    required this.previous,
    required this.isCurrent,
    required this.now,
  });

  final GuidanceRevision revision;
  final GuidanceRevision? previous;
  final bool isCurrent;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = revision.content;
    final prev = previous;
    final changed = prev == null ? const <ContentField>{} : changedFields(prev.content, c);
    final rows = <(String, String?)>[
      (GuidanceStrings.fieldOccurred, formatOccurred(c, now: now)),
      (GuidanceStrings.fieldKind, c.kind.label),
      (GuidanceStrings.fieldStatus, c.status.label),
      (GuidanceStrings.fieldTitle, c.title),
      (GuidanceStrings.fieldPlace, c.place),
      (GuidanceStrings.fieldParticipants,
          c.participants.isEmpty ? null : c.participants.map((p) => p.displayName).join(' · ')),
      (GuidanceStrings.fieldFacts, c.facts),
      (GuidanceStrings.fieldQuotes, c.quotes),
      (GuidanceStrings.fieldActions, c.actions),
    ];
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        side: BorderSide(color: isCurrent ? AppColors.gold : AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(GuidanceStrings.revisionTitle(revision.revisionNo), style: AppTextStyles.heading),
                const SizedBox(width: AppSizes.spacing8),
                if (isCurrent) _tag(GuidanceStrings.revisionCurrent),
                if (revision.revisionNo == 1) _tag(GuidanceStrings.revisionFirst),
                const Spacer(),
                Text(formatStamp(revision.savedAt, now: now), style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
              ],
            ),
            if (changed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSizes.spacing4),
                child: Text(
                  GuidanceStrings.changedLabel(
                    [for (final f in ContentField.values) if (changed.contains(f)) f.label].join(', '),
                  ),
                  style: AppTextStyles.bodyS.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: AppSizes.spacing8),
            for (final (label, value) in rows)
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spacing4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 64, child: Text(label, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub))),
                      Expanded(child: Text(value, style: AppTextStyles.bodyS)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
    margin: const EdgeInsets.only(right: AppSizes.spacing4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.lineStrong),
      borderRadius: BorderRadius.circular(AppSizes.radius4),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub)),
  );
}
```

> 바뀐 칸 문구는 `ContentField.values` 순서로 잇는다 — 테스트가 `진행 상태, 경과` 순서를 기대한다.

- [ ] **Step 8: 라우트를 고친다**

지도 기록 `GoRoute`의 `routes`를 아래로 바꾼다(`new`는 그대로, `record/:id/edit`는 `record/:id` 하위로 옮긴다):

```dart
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const GuidanceEditScreen(),
                ),
                GoRoute(
                  path: 'record/:id',
                  builder: (context, state) => GuidanceDetailScreen(
                    recordId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => GuidanceEditScreen(
                        recordId: int.tryParse(state.pathParameters['id'] ?? ''),
                      ),
                    ),
                    GoRoute(
                      path: 'history',
                      builder: (context, state) => GuidanceHistoryScreen(
                        recordId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                      ),
                    ),
                  ],
                ),
              ],
```

- [ ] **Step 9: 통과를 확인한다**

Run: `flutter test test/features/guidance/ && flutter analyze`
Expected: 전부 PASS, `No issues found!`

- [ ] **Step 10: 커밋**

```bash
git add pubspec.yaml pubspec.lock lib/features/guidance lib/core test/features/guidance
git commit -m "feat(guidance): 기록 보기·수정 이력·첨부 재생과 해시 확인

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017CsGY18wT1wE3iKefCxJo7"
```

---
### Task 8: 첨부 넣기 — 앱 안 녹음 · 녹음 파일·사진 가져오기 · 붙이는 순간 자동 저장

**Files:**
- Modify: `pubspec.yaml` (`record: ^7.1.1`, `wakelock_plus: ^1.3.3`)
- Create: `lib/features/guidance/presentation/recording/guidance_recorder.dart`, `lib/features/guidance/presentation/recording/attachment_importer.dart`, `lib/features/guidance/presentation/recording/recording_screen.dart`
- Modify: `lib/features/guidance/presentation/screens/guidance_edit_screen.dart` (첨부 칸), `lib/core/constants/app_colors.dart` (녹음 화면 토큰 셋 — **추가만**, 기존 값 무수정), `lib/core/constants/strings/guidance_strings.dart`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`
- Test: `test/features/guidance/recording/recording_screen_test.dart`, `test/features/guidance/presentation/guidance_edit_attachments_test.dart`, `test/features/guidance/recording/mic_wiring_test.dart`, `test/core/theme/recording_contrast_test.dart`

**Interfaces:**
- Consumes: Task 3 `GuidanceFileStore.newRecordingPath`, Task 4 `GuidanceActions.attachRecording/attachImported/removeAttachment`, Task 5 `SystemSheetGuard`, Task 6 `_ensureRecord`, Task 7 `AttachmentTile`.
- Produces:
  - `abstract class GuidanceRecorder { Future<bool> ensurePermission(); Future<void> start(String path); Future<String?> stop(); Future<void> dispose(); }`, `guidanceRecorderFactoryProvider` (`Provider<GuidanceRecorder Function()>`)
  - `class PickedFile { final String path; final String name; }`, `abstract class AttachmentImporter { Future<PickedFile?> pickAudio(); Future<PickedFile?> pickImage(); }`, `attachmentImporterProvider`
  - `class RecordingResult { final String path; final int durationMs; final DateTime startedAt; }`, `RecordingScreen({required String title})` — 키 `stopKey`, `settingsKey`; 결과는 `Navigator.pop(RecordingResult)`
  - `AppColors.recordingBackground`, `AppColors.onRecording`, `AppColors.recordingLive`
  - `GuidanceEditScreen` 키 추가: `recordKey`, `importAudioKey`, `importImageKey`

- [ ] **Step 1: 의존성·권한·문자열·색**

Run: `flutter pub add record:^7.1.1 wakelock_plus:^1.3.3`

`ios/Runner/Info.plist`에(`NSFaceIDUsageDescription` 근처):

```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>지도 기록에 대화를 녹음할 때 마이크를 사용합니다.</string>
```

`android/app/src/main/AndroidManifest.xml`의 다른 `<uses-permission>` 줄들 옆에:

```xml
    <!-- 지도 기록의 앱 안 녹음. 사용자가 녹음 버튼을 누를 때만 요청한다. -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
```

`guidance_strings.dart` 끝에:

```dart
  // 첨부 넣기
  static const record = '녹음하기';
  static const importAudio = '녹음 파일 가져오기';
  static const importImage = '사진 가져오기';
  static const importHintSchoolPhone = '학부모 통화는 학교 전화 사용이 원칙입니다.';
  static const importHintCallRecording =
      '아이폰 통화 녹음(iOS 18.1 이상)은 메모 앱에 저장됩니다. 메모에서 공유 › 파일에 저장한 뒤 가져오세요.';
  static const removeAttachmentTitle = '첨부에서 뺄까요?';
  static const removeAttachmentMessage = '목록에서만 빠지고 파일은 지우지 않습니다. 수정 이력에 남습니다.';
  static const removeAttachmentConfirm = '빼기';

  // 녹음 화면
  static const recordingLive = '녹음 중';
  static const recordingStop = '녹음 멈추기';
  static const recordingStopHint = '멈추면 이 기록에 붙어요';
  static const recordingLegal =
      '대화에 직접 참여하는 경우에만 녹음하세요. 자리를 비운 사이의 녹음은 불법이 될 수 있습니다.';
  static const recordingNotice = '가능하면 녹음한다고 먼저 알려 주세요.';
  static const recordingScreenOn = '녹음하는 동안 화면이 꺼지지 않아요 · 앱을 떠나면 여기까지 저장돼요';
  static const micDenied = '마이크 권한이 꺼져 있어요';
  static const micDeniedBody = '설정에서 공직플랜의 마이크를 켜면 녹음할 수 있습니다.';
  static const openSettings = '설정 열기';
```

`lib/core/constants/app_colors.dart`에 녹음 화면 토큰 셋을 **추가**한다(두 테마 같은 값 — 녹음 화면은 테마와 무관하게 어둡다). `memoPink`를 넣은 다섯 자리와 같은 방식이다:
- `_Palette` 생성자 인자: `required this.recordingBackground, required this.onRecording, required this.recordingLive,`
- 필드: `final Color recordingBackground; final Color onRecording; final Color recordingLive;`
- 다크·라이트 인스턴스 둘 다: `recordingBackground: Color(0xFF0F1A2C), onRecording: Color(0xFFF3EFE6), recordingLive: Color(0xFFF08A7E),`
- getter: `static Color get recordingBackground => _current.recordingBackground;` 외 둘.

`test/core/theme/recording_contrast_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';

import '../../helpers/contrast.dart';

void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  for (final b in Brightness.values) {
    test('$b: 녹음 화면의 글자·녹음 중 표시가 4.5:1 이상', () {
      AppColors.applyBrightness(b);
      expect(contrastRatio(AppColors.onRecording, AppColors.recordingBackground), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(AppColors.recordingLive, AppColors.recordingBackground), greaterThanOrEqualTo(4.5));
    });
  }
}
```

`test/features/guidance/recording/mic_wiring_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS 마이크 사용 문구가 있다', () {
    expect(File('ios/Runner/Info.plist').readAsStringSync(), contains('NSMicrophoneUsageDescription'));
  });

  test('Android가 RECORD_AUDIO를 선언한다', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android.permission.RECORD_AUDIO'),
    );
  });
}
```

Run: `flutter test test/core/theme/recording_contrast_test.dart test/features/guidance/recording/mic_wiring_test.dart`
Expected: PASS

- [ ] **Step 2: 녹음기·가져오기 래퍼를 만든다**

`lib/features/guidance/presentation/recording/guidance_recorder.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../lock/system_sheet_guard.dart';

/// 앱 안 녹음. 위젯 테스트에서 플러그인을 부르지 않으려고 인터페이스로 둔다.
abstract class GuidanceRecorder {
  Future<bool> ensurePermission();
  Future<void> start(String path);
  Future<String?> stop();
  Future<void> dispose();
}

/// AAC `.m4a`, 모노 64kbps(1시간 약 30MB). 녹음 동안 화면을 켜 둔다 — 백그라운드 녹음은
/// 하지 않으므로 화면이 꺼지면 녹음이 멈춘다(스펙 결정 A).
class RecordGuidanceRecorder implements GuidanceRecorder {
  final _recorder = AudioRecorder();

  /// 권한 창도 앱을 비활성으로 만든다 — 가드로 감싸야 잠금·녹음 중단이 일어나지 않는다.
  @override
  Future<bool> ensurePermission() => SystemSheetGuard.run(() => _recorder.hasPermission());

  @override
  Future<void> start(String path) async {
    await WakelockPlus.enable();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
      path: path,
    );
  }

  @override
  Future<String?> stop() async {
    try {
      return await _recorder.stop();
    } finally {
      await WakelockPlus.disable();
    }
  }

  @override
  Future<void> dispose() async {
    await WakelockPlus.disable();
    await _recorder.dispose();
  }
}

final guidanceRecorderFactoryProvider = Provider<GuidanceRecorder Function()>(
  (ref) => RecordGuidanceRecorder.new,
);
```

`lib/features/guidance/presentation/recording/attachment_importer.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lock/system_sheet_guard.dart';

class PickedFile {
  const PickedFile({required this.path, required this.name});
  final String path;
  final String name;
}

abstract class AttachmentImporter {
  Future<PickedFile?> pickAudio();
  Future<PickedFile?> pickImage();
}

/// 고르기 창은 앱을 비활성(Android는 백그라운드)으로 만든다 — 반드시 가드 안에서 연다.
class FilePickerImporter implements AttachmentImporter {
  /// 음성 메모·통화 녹음·일반 녹음기의 확장자. `FileType.audio`는 iOS에서 **음악 보관함**을 열어
  /// 녹음 파일을 고를 수 없으므로 파일 창(custom)을 쓴다.
  static const audioExtensions = ['m4a', 'mp3', 'wav', 'aac', 'caf', 'amr', '3gp', 'ogg'];

  @override
  Future<PickedFile?> pickAudio() => SystemSheetGuard.run(() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: audioExtensions);
    return _first(r);
  });

  /// `allowCompression: false` — iOS 사진 고르기가 원본 표현(HEIC 그대로)을 넘긴다.
  /// 켜 두면 호환 형식으로 다시 인코딩돼 원본과 다른 바이트가 된다.
  @override
  Future<PickedFile?> pickImage() => SystemSheetGuard.run(() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowCompression: false);
    return _first(r);
  });

  PickedFile? _first(FilePickerResult? r) {
    final f = r?.files.firstOrNull;
    final path = f?.path;
    if (f == null || path == null) return null;
    return PickedFile(path: path, name: f.name);
  }
}

final attachmentImporterProvider = Provider<AttachmentImporter>((ref) => FilePickerImporter());
```

- [ ] **Step 3: 녹음 화면 실패 테스트**

`test/features/guidance/recording/recording_screen_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/presentation/lock/system_sheet_guard.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/recording/guidance_recorder.dart';
import 'package:planroutine/features/guidance/presentation/recording/recording_screen.dart';

class FakeRecorder implements GuidanceRecorder {
  FakeRecorder({this.permitted = true});
  final bool permitted;
  String? startedAt;
  var stopped = 0;
  @override
  Future<bool> ensurePermission() async => permitted;
  @override
  Future<void> start(String path) async {
    startedAt = path;
    File(path).writeAsStringSync('rec');
  }

  @override
  Future<String?> stop() async {
    stopped++;
    return startedAt;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory base;
  late FakeRecorder rec;
  RecordingResult? result;
  var popped = false;

  setUp(() async {
    SystemSheetGuard.reset();
    base = await Directory.systemTemp.createTemp('rec_screen');
    result = null;
    popped = false;
  });
  tearDown(() async => base.delete(recursive: true));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
  }

  Future<void> pump(WidgetTester tester, {bool permitted = true}) async {
    rec = FakeRecorder(permitted: permitted);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRecorderFactoryProvider.overrideWithValue(() => rec),
          guidanceFileStoreProvider.overrideWithValue(GuidanceFileStore(baseDir: () async => base)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<RecordingResult>(
                  MaterialPageRoute(builder: (_) => const RecordingScreen(title: '복도 다툼')),
                );
                popped = true;
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await settle(tester);
  }

  testWidgets('허락하면 첨부 폴더 안에 녹음하고, 멈추면 결과를 돌려준다', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.recordingLive), findsOneWidget);
    expect(find.text(GuidanceStrings.recordingLegal), findsOneWidget);
    expect(find.text(GuidanceStrings.recordingNotice), findsOneWidget);
    expect(rec.startedAt?.contains(GuidanceFileStore.folder), isTrue);
    await tester.tap(find.byKey(RecordingScreen.stopKey));
    await settle(tester);
    expect(popped, isTrue);
    expect(result?.path, rec.startedAt);
    expect(result?.durationMs, greaterThanOrEqualTo(0));
  });

  testWidgets('권한이 없으면 안내하고 녹음을 시작하지 않는다', (tester) async {
    await pump(tester, permitted: false);
    expect(find.text(GuidanceStrings.micDenied), findsOneWidget);
    expect(find.byKey(RecordingScreen.settingsKey), findsOneWidget);
    expect(rec.startedAt, isNull);
  });

  testWidgets('전화가 오거나 앱을 떠나면 그때까지 저장하고 돌아간다', (tester) async {
    await pump(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(tester);
    expect(rec.stopped, 1);
    expect(popped, isTrue);
    expect(result?.path, rec.startedAt);
  });

  testWidgets('시스템 창 동안의 비활성에는 멈추지 않는다', (tester) async {
    await pump(tester);
    final sheet = Completer<void>();
    final running = SystemSheetGuard.run(() => sheet.future);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(tester);
    expect(rec.stopped, 0);
    sheet.complete();
    await running;
  });

  testWidgets('뒤로 가기도 녹음을 버리지 않고 결과를 돌려준다', (tester) async {
    await pump(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(rec.stopped, 1);
    expect(result?.path, rec.startedAt);
  });
}
```

Run: `flutter test test/features/guidance/recording/recording_screen_test.dart`
Expected: FAIL — 화면 없음.

- [ ] **Step 4: 녹음 화면을 구현한다**

`lib/features/guidance/presentation/recording/recording_screen.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../lock/system_sheet_guard.dart';
import '../providers/guidance_providers.dart';
import 'guidance_recorder.dart';

class RecordingResult {
  const RecordingResult({required this.path, required this.durationMs, required this.startedAt});
  final String path;
  final int durationMs;
  final DateTime startedAt;
}

enum _Phase { checking, denied, recording }

/// 녹음 화면. 녹음 동안 화면이 꺼지지 않고, **앱을 떠나거나 전화가 오거나 뒤로 가면
/// 그때까지 저장해 결과를 돌려준다** — 녹음을 버리는 길이 없다.
class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key, required this.title});

  final String title;

  static const stopKey = Key('recording_stop');
  static const settingsKey = Key('recording_settings');

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> with WidgetsBindingObserver {
  late final GuidanceRecorder _recorder = ref.read(guidanceRecorderFactoryProvider)();
  var _phase = _Phase.checking;
  String? _path;
  DateTime? _startedAt;
  Timer? _ticker;
  var _elapsed = Duration.zero;
  var _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _begin();
  }

  Future<void> _begin() async {
    final ok = await _recorder.ensurePermission();
    if (!mounted) return;
    if (!ok) {
      setState(() => _phase = _Phase.denied);
      return;
    }
    final path = await ref.read(guidanceFileStoreProvider).newRecordingPath();
    await _recorder.start(path);
    if (!mounted) return;
    final started = DateTime.now();
    setState(() {
      _path = path;
      _startedAt = started;
      _phase = _Phase.recording;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(started));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.detached) return;
    if (SystemSheetGuard.shouldIgnore(state)) return;
    _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _ticker?.cancel();
    final path = _path;
    final started = _startedAt;
    if (path == null || started == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final out = await _recorder.stop() ?? path;
    final ms = DateTime.now().difference(started).inMilliseconds;
    if (mounted) {
      Navigator.of(context).pop(RecordingResult(path: out, durationMs: ms, startedAt: started));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String get _clock {
    final s = _elapsed.inSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '${m.toString().padLeft(2, '0')}:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final on = AppColors.onRecording;
    return PopScope(
      canPop: _phase != _Phase.recording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: AppColors.recordingBackground,
        appBar: AppBar(
          backgroundColor: AppColors.recordingBackground,
          foregroundColor: on,
          automaticallyImplyLeading: _phase != _Phase.recording,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spacing24),
            child: switch (_phase) {
              _Phase.checking => const SizedBox.shrink(),
              _Phase.denied => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_off, size: 48, color: on),
                  const SizedBox(height: AppSizes.spacing12),
                  Text(GuidanceStrings.micDenied, style: TextStyle(color: on, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSizes.spacing8),
                  Text(GuidanceStrings.micDeniedBody, textAlign: TextAlign.center, style: TextStyle(color: on, fontSize: 15)),
                  const SizedBox(height: AppSizes.spacing20),
                  FilledButton(
                    key: RecordingScreen.settingsKey,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.goldFill, foregroundColor: AppColors.onGold),
                    onPressed: openAppSettings,
                    child: const Text(GuidanceStrings.openSettings),
                  ),
                ],
              ),
              _Phase.recording => Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, size: 10, color: AppColors.recordingLive),
                      const SizedBox(width: AppSizes.spacing8),
                      Text(GuidanceStrings.recordingLive,
                          style: TextStyle(color: AppColors.recordingLive, fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  Text(widget.title, style: TextStyle(color: on, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Text(
                    _clock,
                    style: TextStyle(color: on, fontSize: 64, fontWeight: FontWeight.w300,
                        fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: GuidanceStrings.recordingStop,
                    child: InkResponse(
                      key: RecordingScreen.stopKey,
                      onTap: _finish,
                      radius: 48,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on, width: 3)),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.recordingLive,
                              borderRadius: BorderRadius.circular(AppSizes.radius4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  Text(GuidanceStrings.recordingStopHint, style: TextStyle(color: on, fontSize: 14)),
                  const Spacer(),
                  Text(GuidanceStrings.recordingLegal, textAlign: TextAlign.center,
                      style: TextStyle(color: on, fontSize: 14, height: 1.5)),
                  const SizedBox(height: AppSizes.spacing4),
                  Text(GuidanceStrings.recordingNotice, textAlign: TextAlign.center,
                      style: TextStyle(color: on, fontSize: 14, height: 1.5)),
                  const SizedBox(height: AppSizes.spacing12),
                  Text(GuidanceStrings.recordingScreenOn, textAlign: TextAlign.center,
                      style: TextStyle(color: on, fontSize: 13)),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}
```

> `FontFeature`는 `dart:ui`에 있다 — `import 'dart:ui' show FontFeature;`를 더한다.

Run: `flutter test test/features/guidance/recording/recording_screen_test.dart`
Expected: PASS(5건).

- [ ] **Step 5: 편집 화면 첨부 실패 테스트**

`test/features/guidance/presentation/guidance_edit_attachments_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/recording/attachment_importer.dart';
import 'package:planroutine/features/guidance/presentation/recording/guidance_recorder.dart';
import 'package:planroutine/features/guidance/presentation/recording/recording_screen.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_edit_screen.dart';
import 'package:planroutine/features/guidance/presentation/widgets/attachment_tile.dart';

import '../../../helpers/test_database.dart';

class FakeImporter implements AttachmentImporter {
  FakeImporter(this.file);
  final File file;
  @override
  Future<PickedFile?> pickAudio() async => PickedFile(path: file.path, name: '음성 메모 1002.m4a');
  @override
  Future<PickedFile?> pickImage() async => PickedFile(path: file.path, name: 'IMG_0001.HEIC');
}

class FakeRecorder implements GuidanceRecorder {
  String? path;
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<void> start(String p) async {
    path = p;
    File(p).writeAsStringSync('rec');
  }

  @override
  Future<String?> stop() async => path;
  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;
  late Directory base;
  late File source;

  setUp(() async {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
    base = await Directory.systemTemp.createTemp('edit_att');
    source = File('${base.path}/pick.bin')..writeAsStringSync('abc');
  });
  tearDown(() async {
    await db.close();
    await base.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRepositoryProvider.overrideWithValue(repo),
          guidancePeopleRepositoryProvider.overrideWithValue(GuidancePeopleRepository(dbHelper: db)),
          guidanceFileStoreProvider.overrideWithValue(GuidanceFileStore(baseDir: () async => base)),
          attachmentImporterProvider.overrideWithValue(FakeImporter(source)),
          guidanceRecorderFactoryProvider.overrideWithValue(FakeRecorder.new),
        ],
        child: const MaterialApp(home: GuidanceEditScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('가져오기 안내 두 줄이 보인다', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.importHintSchoolPhone), findsOneWidget);
    expect(find.text(GuidanceStrings.importHintCallRecording), findsOneWidget);
  });

  testWidgets('새 기록에 사진을 붙이면 그 순간 기록이 저장되고, 쓰던 글은 남는다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.factsKey), '쓰던 경과');
    await tester.tap(find.byKey(GuidanceEditScreen.importImageKey));
    await settle(tester);
    final list = await tester.runAsync(repo.getActive);
    expect(list?.single.content.title, GuidanceStrings.untitled);
    expect(list?.single.content.facts, '쓰던 경과');
    final atts = await tester.runAsync(() => repo.getAttachments(list?.single.id ?? -1));
    expect(atts?.single.type, AttachmentType.image);
    expect(atts?.single.originalName, 'IMG_0001.HEIC');
    expect(find.text('쓰던 경과'), findsOneWidget);
    expect(find.byType(AttachmentTile), findsOneWidget);
  });

  testWidgets('녹음을 마치면 기록이 저장되고 녹음이 붙는다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidanceEditScreen.recordKey));
    await settle(tester);
    expect(find.byType(RecordingScreen), findsOneWidget);
    await tester.tap(find.byKey(RecordingScreen.stopKey));
    await settle(tester);
    final list = await tester.runAsync(repo.getActive);
    final atts = await tester.runAsync(() => repo.getAttachments(list?.single.id ?? -1));
    expect(atts?.single.source, AttachmentSource.recorded);
    expect(atts?.single.type, AttachmentType.audio);
  });

  testWidgets('첨부를 빼면 묻고, 빼면 목록에서 사라지되 행은 남는다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidanceEditScreen.importAudioKey));
    await settle(tester);
    final id = (await tester.runAsync(repo.getActive))?.single.id ?? -1;
    final att = (await tester.runAsync(() => repo.getAttachments(id)))?.single;
    await tester.tap(find.byKey(AttachmentTile.removeKey(att?.id ?? -1)));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.removeAttachmentTitle), findsOneWidget);
    await tester.tap(find.text(GuidanceStrings.removeAttachmentConfirm));
    await settle(tester);
    expect(find.byType(AttachmentTile), findsNothing);
    final after = await tester.runAsync(() => repo.getAttachments(id));
    expect(after?.single.isRemoved, isTrue);
  });
}
```

Run: `flutter test test/features/guidance/presentation/guidance_edit_attachments_test.dart`
Expected: FAIL — 키 없음.

- [ ] **Step 6: 편집 화면에 첨부 칸을 더한다**

`guidance_edit_screen.dart`:
- import 추가: `../../domain/guidance_models.dart`, `../recording/attachment_importer.dart`, `../recording/recording_screen.dart`, `../widgets/attachment_tile.dart`
- `_ensureRecord` 위의 `// ignore: unused_element` 주석을 지운다.
- 키 셋 추가:

```dart
  static const recordKey = Key('guidance_edit_record');
  static const importAudioKey = Key('guidance_edit_import_audio');
  static const importImageKey = Key('guidance_edit_import_image');
```

- State에 메서드 셋:

```dart
  Future<void> _record() async {
    final title = _title.text.trim();
    final result = await Navigator.of(context).push<RecordingResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecordingScreen(title: title.isEmpty ? GuidanceStrings.untitled : title),
      ),
    );
    if (result == null || !mounted) return;
    // 녹음이 끝난 순간 기록이 없으면 지금 만든다 — 실수로 나가도 녹음이 사라지지 않게.
    final id = await _ensureRecord();
    await ref.read(guidanceActionsProvider).attachRecording(
      recordId: id,
      path: result.path,
      durationMs: result.durationMs,
      startedAt: result.startedAt,
    );
  }

  Future<void> _import(AttachmentType type) async {
    final importer = ref.read(attachmentImporterProvider);
    final picked = type == AttachmentType.audio ? await importer.pickAudio() : await importer.pickImage();
    if (picked == null || !mounted) return;
    final id = await _ensureRecord();
    await ref.read(guidanceActionsProvider).attachImported(
      recordId: id,
      sourcePath: picked.path,
      type: type,
      originalName: picked.name,
    );
  }

  Future<void> _removeAttachment(GuidanceAttachment a) async {
    final id = a.id;
    if (id == null) return;
    final ok = await ConfirmDialog.show(
      context: context,
      useRootNavigator: false,
      title: GuidanceStrings.removeAttachmentTitle,
      message: GuidanceStrings.removeAttachmentMessage,
      confirmLabel: GuidanceStrings.removeAttachmentConfirm,
    );
    if (ok) await ref.read(guidanceActionsProvider).removeAttachment(id);
  }

  List<Widget> _attachmentsSection(DateTime now) {
    final id = _recordId;
    final attachments = id == null
        ? const <GuidanceAttachment>[]
        : [
            for (final a in ref.watch(guidanceAttachmentsProvider(id)).valueOrNull ?? const <GuidanceAttachment>[])
              if (!a.isRemoved) a,
          ];
    return [
      _gap(),
      _label(GuidanceStrings.labelAttachments),
      for (final a in attachments)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
          child: AttachmentTile(attachment: a, now: now, onRemove: () => _removeAttachment(a)),
        ),
      Wrap(
        spacing: AppSizes.spacing8,
        runSpacing: AppSizes.spacing8,
        children: [
          OutlinedButton.icon(
            key: GuidanceEditScreen.recordKey,
            onPressed: _record,
            icon: Icon(Icons.fiber_manual_record, color: AppColors.error),
            label: const Text(GuidanceStrings.record),
          ),
          OutlinedButton.icon(
            key: GuidanceEditScreen.importAudioKey,
            onPressed: () => _import(AttachmentType.audio),
            icon: const Icon(Icons.audio_file_outlined),
            label: const Text(GuidanceStrings.importAudio),
          ),
          OutlinedButton.icon(
            key: GuidanceEditScreen.importImageKey,
            onPressed: () => _import(AttachmentType.image),
            icon: const Icon(Icons.image_outlined),
            label: const Text(GuidanceStrings.importImage),
          ),
        ],
      ),
      _hint(GuidanceStrings.importHintSchoolPhone),
      _hint(GuidanceStrings.importHintCallRecording),
    ];
  }
```

- `build`의 `ListView` children 끝(`_hint(GuidanceStrings.actionsHint),` 뒤)에 `..._attachmentsSection(now),`.

- [ ] **Step 7: 통과를 확인한다**

Run: `flutter test test/features/guidance/ test/core/theme/ && flutter analyze`
Expected: 전부 PASS, `No issues found!`

- [ ] **Step 8: 두 플랫폼 빌드**

Run: `flutter build apk --debug 2>&1 | tail -3 && flutter build ios --simulator --debug 2>&1 | tail -3`
Expected: 둘 다 `✓ Built`

- [ ] **Step 9: 커밋**

```bash
git add pubspec.yaml pubspec.lock lib ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml test
git commit -m "feat(guidance): 앱 안 녹음·녹음 파일·사진 가져오기 — 붙이는 순간 기록 저장

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017CsGY18wT1wE3iKefCxJo7"
```

---

### Task 9: 명단 관리 · 삭제한 기록

**Files:**
- Create: `lib/features/guidance/presentation/screens/guidance_people_screen.dart`, `lib/features/guidance/presentation/widgets/person_edit_sheet.dart`, `lib/features/guidance/presentation/screens/guidance_trash_screen.dart`
- Modify: `lib/core/router/app_router.dart` (`people`, `trash`), `lib/core/constants/strings/guidance_strings.dart`
- Test: `test/features/guidance/presentation/guidance_people_screen_test.dart`, `test/features/guidance/presentation/guidance_trash_screen_test.dart`

**Interfaces:**
- Consumes: Task 4 provider·`GuidanceActions`, Task 1 `parseRosterPaste`·`countRecordsByPerson`·`formatStamp`.
- Produces:
  - `GuidancePeopleScreen` — 키 `addKey`, `pasteKey`, `archivedKey`, `personKey(int id)`
  - `showPersonEditSheet(BuildContext, {GuidancePerson? person})` — 키 `PersonEditSheet.nameKey`, `memoKey`, `saveKey`, `archiveKey`, `roleKey(PersonRole)`
  - `GuidanceTrashScreen` — 키 `restoreKey(int)`, `purgeKey(int)`

- [ ] **Step 1: 문자열**

```dart
  // 명단 관리
  static String studentsHeader(int n) => '학생 · $n명';
  static const othersHeader = '보호자 · 교직원 · 기타';
  static String archivedHeader(int n) => '보관된 사람 · $n명';
  static String recordCount(int n) => '기록 $n';
  static const pasteTitle = '여러 명 붙여넣기';
  static const pasteHint = '한 줄에 한 명씩. 앞의 번호는 지워집니다.';
  static String pastePreview(int n) => '$n명을 학생으로 넣습니다';
  static const pasteConfirm = '넣기';
  static String pasteDone(int n) => '$n명을 넣었어요';
  static const personAddTitle = '사람 추가';
  static const personEditTitle = '사람 고치기';
  static const personName = '이름';
  static const personMemo = '소속·관계';
  static const archive = '보관';
  static const unarchive = '되살리기';
  static const archiveNote = '보관해도 옛 기록의 이름은 그대로 남습니다.';

  // 삭제한 기록
  static const trashIntro = '자동으로 지워지지 않습니다. 영구 삭제하면 모든 판과 녹음·사진이 함께 지워지고 되돌릴 수 없습니다.';
  static const trashEmpty = '삭제한 기록이 없습니다';
  static String deletedAt(String when) => '삭제 $when';
  static const restore = '되살리기';
  static const purge = '영구 삭제';
  static const purgeTitle = '영구 삭제할까요?';
  static const purgeMessage = '이 기록의 모든 판과 첨부 파일이 지워집니다. 되돌릴 수 없습니다.';
```

- [ ] **Step 2: 실패 테스트를 쓴다**

`test/features/guidance/presentation/guidance_people_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_people_screen.dart';
import 'package:planroutine/features/guidance/presentation/widgets/person_edit_sheet.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidancePeopleRepository people;
  late GuidanceRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    people = GuidancePeopleRepository(dbHelper: db);
    repo = GuidanceRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidancePeopleRepositoryProvider.overrideWithValue(people),
          guidanceRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: GuidancePeopleScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('여러 명 붙여넣기 — 번호를 걷어내고 학생으로 넣는다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidancePeopleScreen.pasteKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1. 김하늘\n2. 이도윤\n');
    await tester.pump();
    expect(find.text(GuidanceStrings.pastePreview(2)), findsOneWidget);
    await tester.tap(find.text(GuidanceStrings.pasteConfirm));
    await settle(tester);
    expect(find.text('김하늘'), findsOneWidget);
    expect(find.text('이도윤'), findsOneWidget);
    expect(find.text(GuidanceStrings.studentsHeader(2)), findsOneWidget);
  });

  testWidgets('사람마다 등장한 기록 수가 보인다', (tester) async {
    await tester.runAsync(() async {
      final p = await people.add(const GuidancePerson(name: '김하늘'));
      await repo.create(GuidanceContent(title: 'a', participants: [p.toParticipant()]));
      await repo.create(GuidanceContent(title: 'b', participants: [p.toParticipant(), const Participant(name: '박서준')]));
    });
    await pump(tester);
    expect(find.text(GuidanceStrings.recordCount(2)), findsOneWidget);
  });

  testWidgets('사람을 추가하고 고치고 보관하면 보관 묶음으로 간다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidancePeopleScreen.addKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(PersonEditSheet.nameKey), '이도윤 보호자');
    await tester.tap(find.byKey(PersonEditSheet.roleKey(PersonRole.guardian)));
    await tester.enterText(find.byKey(PersonEditSheet.memoKey), '어머니');
    await tester.tap(find.byKey(PersonEditSheet.saveKey));
    await settle(tester);
    expect(find.text('이도윤 보호자'), findsOneWidget);
    expect(find.text(GuidanceStrings.othersHeader), findsOneWidget);

    await tester.tap(find.text('이도윤 보호자'));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.archiveNote), findsOneWidget);
    await tester.tap(find.byKey(PersonEditSheet.archiveKey));
    await settle(tester);
    expect(find.text(GuidanceStrings.archivedHeader(1)), findsOneWidget);
    expect((await tester.runAsync(people.getArchived))?.single.name, '이도윤 보호자');
  });

  testWidgets('보관된 사람을 되살린다', (tester) async {
    await tester.runAsync(() async {
      final p = await people.add(const GuidancePerson(name: '지난해 학생'));
      await people.archive(p.id ?? -1);
    });
    await pump(tester);
    await tester.tap(find.byKey(GuidancePeopleScreen.archivedKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(GuidanceStrings.unarchive));
    await settle(tester);
    expect((await tester.runAsync(people.getActive))?.single.name, '지난해 학생');
  });
}
```

`test/features/guidance/presentation/guidance_trash_screen_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_trash_screen.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;
  late Directory base;
  late GuidanceFileStore files;

  setUp(() async {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
    base = await Directory.systemTemp.createTemp('g_trash');
    files = GuidanceFileStore(baseDir: () async => base);
  });
  tearDown(() async {
    await db.close();
    await base.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRepositoryProvider.overrideWithValue(repo),
          guidanceFileStoreProvider.overrideWithValue(files),
        ],
        child: const MaterialApp(home: GuidanceTrashScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('비어 있으면 안내 문구', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.trashEmpty), findsOneWidget);
    expect(find.text(GuidanceStrings.trashIntro), findsOneWidget);
  });

  testWidgets('되살리면 목록으로 돌아간다', (tester) async {
    final id = await tester.runAsync(() async {
      final id = await repo.create(const GuidanceContent(title: '지운 것'));
      await repo.softDelete(id);
      return id;
    });
    await pump(tester);
    await tester.tap(find.byKey(GuidanceTrashScreen.restoreKey(id ?? -1)));
    await settle(tester);
    expect((await tester.runAsync(repo.getActive))?.single.id, id);
    expect(find.text('지운 것'), findsNothing);
  });

  testWidgets('영구 삭제는 묻고, 확인하면 기록과 첨부 파일을 지운다', (tester) async {
    late GuidanceAttachment att;
    final id = await tester.runAsync(() async {
      final id = await repo.create(const GuidanceContent(title: '지운 것'));
      final stored = await files.importCopy((File('${base.path}/a.jpg')..writeAsStringSync('a')).path);
      att = await repo.addAttachment(
        GuidanceAttachment(
          recordId: id,
          type: AttachmentType.image,
          source: AttachmentSource.imported,
          fileName: stored.fileName,
          sha256: stored.sha256,
          byteSize: stored.byteSize,
          attachedAt: DateTime.now().toIso8601String(),
        ),
      );
      await repo.softDelete(id);
      return id;
    });
    await pump(tester);
    await tester.tap(find.byKey(GuidanceTrashScreen.purgeKey(id ?? -1)));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.purgeTitle), findsOneWidget);
    await tester.tap(find.text(GuidanceStrings.purge).last);
    await settle(tester);
    expect(await tester.runAsync(repo.getDeleted), isEmpty);
    final file = await tester.runAsync(() => files.fileOf(att.fileName));
    expect(await tester.runAsync(() async => file?.exists()), isFalse);
  });
}
```

Run: `flutter test test/features/guidance/presentation/guidance_people_screen_test.dart test/features/guidance/presentation/guidance_trash_screen_test.dart`
Expected: FAIL — 화면 없음.

- [ ] **Step 3: 사람 편집 시트를 구현한다**

`lib/features/guidance/presentation/widgets/person_edit_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../providers/guidance_providers.dart';

Future<void> showPersonEditSheet(BuildContext context, {GuidancePerson? person}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PersonEditSheet(person: person),
    );

class PersonEditSheet extends ConsumerStatefulWidget {
  const PersonEditSheet({super.key, this.person});

  final GuidancePerson? person;

  static const nameKey = Key('person_name');
  static const memoKey = Key('person_memo');
  static const saveKey = Key('person_save');
  static const archiveKey = Key('person_archive');
  static Key roleKey(PersonRole r) => Key('person_role_${r.dbValue}');

  @override
  ConsumerState<PersonEditSheet> createState() => _PersonEditSheetState();
}

class _PersonEditSheetState extends ConsumerState<PersonEditSheet> {
  late final _name = TextEditingController(text: widget.person?.name ?? '');
  late final _memo = TextEditingController(text: widget.person?.memo ?? '');
  late var _role = widget.person?.role ?? PersonRole.student;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    final memo = _memo.text.trim().isEmpty ? null : _memo.text.trim();
    final actions = ref.read(guidanceActionsProvider);
    final existing = widget.person;
    if (existing == null) {
      await actions.addPerson(GuidancePerson(name: name, role: _role, memo: memo));
    } else {
      await actions.updatePerson(existing.copyWith(name: name, role: _role, memo: memo));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _archive() async {
    final id = widget.person?.id;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    await ref.read(guidanceActionsProvider).archivePerson(id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom < 0 ? 0 : bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.person == null ? GuidanceStrings.personAddTitle : GuidanceStrings.personEditTitle,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: AppSizes.spacing12),
              TextField(
                key: PersonEditSheet.nameKey,
                controller: _name,
                autofocus: widget.person == null,
                decoration: const InputDecoration(hintText: GuidanceStrings.personName),
              ),
              const SizedBox(height: AppSizes.spacing12),
              Wrap(
                spacing: AppSizes.spacing8,
                children: [
                  for (final r in PersonRole.values)
                    ChoiceChip(
                      key: PersonEditSheet.roleKey(r),
                      label: Text(r.label),
                      selected: _role == r,
                      onSelected: (_) => setState(() => _role = r),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.spacing12),
              TextField(
                key: PersonEditSheet.memoKey,
                controller: _memo,
                decoration: const InputDecoration(hintText: GuidanceStrings.personMemo),
              ),
              const SizedBox(height: AppSizes.spacing16),
              FilledButton(
                key: PersonEditSheet.saveKey,
                style: FilledButton.styleFrom(backgroundColor: AppColors.goldFill, foregroundColor: AppColors.onGold),
                onPressed: _busy ? null : _save,
                child: const Text(GuidanceStrings.save),
              ),
              if (widget.person != null) ...[
                const SizedBox(height: AppSizes.spacing8),
                TextButton(
                  key: PersonEditSheet.archiveKey,
                  onPressed: _busy ? null : _archive,
                  child: const Text(GuidanceStrings.archive),
                ),
                Text(
                  GuidanceStrings.archiveNote,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 명단 관리 화면을 구현한다**

`lib/features/guidance/presentation/screens/guidance_people_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../providers/guidance_providers.dart';
import '../widgets/person_edit_sheet.dart';

class GuidancePeopleScreen extends ConsumerWidget {
  const GuidancePeopleScreen({super.key});

  static const addKey = Key('people_add');
  static const pasteKey = Key('people_paste');
  static const archivedKey = Key('people_archived');
  static Key personKey(int id) => Key('people_person_$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(guidancePeopleProvider).valueOrNull ?? const <GuidancePerson>[];
    final archived = ref.watch(guidanceArchivedPeopleProvider).valueOrNull ?? const <GuidancePerson>[];
    final counts = countRecordsByPerson(ref.watch(guidanceRecordsProvider).valueOrNull ?? const []);
    final students = [for (final p in active) if (p.role == PersonRole.student) p];
    final others = [for (final p in active) if (p.role != PersonRole.student) p];

    Widget tile(GuidancePerson p) {
      final n = counts[p.id] ?? 0;
      return ListTile(
        key: personKey(p.id ?? -1),
        title: Text(p.name),
        subtitle: Text(p.memo == null ? p.role.label : '${p.role.label} · ${p.memo}'),
        trailing: n == 0 ? null : Text(GuidanceStrings.recordCount(n)),
        onTap: () => showPersonEditSheet(context, person: p),
      );
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.spacing16, AppSizes.spacing16, AppSizes.spacing16, AppSizes.spacing4),
      child: Text(text, style: AppTextStyles.label.copyWith(color: AppColors.sub)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(GuidanceStrings.peopleTitle, style: AppTextStyles.heading),
        actions: [
          TextButton(
            key: pasteKey,
            onPressed: () => _paste(context, ref),
            child: const Text(GuidanceStrings.pasteTitle),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: addKey,
        tooltip: GuidanceStrings.personAddTitle,
        backgroundColor: AppColors.goldFill,
        foregroundColor: AppColors.onGold,
        onPressed: () => showPersonEditSheet(context),
        child: const Icon(Icons.person_add_alt),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.spacing48 * 2),
        children: [
          header(GuidanceStrings.studentsHeader(students.length)),
          for (final p in students) tile(p),
          if (others.isNotEmpty) ...[header(GuidanceStrings.othersHeader), for (final p in others) tile(p)],
          if (archived.isNotEmpty)
            ExpansionTile(
              key: archivedKey,
              title: Text(GuidanceStrings.archivedHeader(archived.length)),
              children: [
                for (final p in archived)
                  ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.role.label),
                    trailing: TextButton(
                      onPressed: () => ref.read(guidanceActionsProvider).unarchivePerson(p.id ?? -1),
                      child: const Text(GuidanceStrings.unarchive),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _paste(BuildContext context, WidgetRef ref) async {
    final names = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PasteSheet(),
    );
    if (names == null || names.isEmpty) return;
    final n = await ref.read(guidanceActionsProvider).addNames(names);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(GuidanceStrings.pasteDone(n))));
    }
  }
}

class _PasteSheet extends StatefulWidget {
  const _PasteSheet();

  @override
  State<_PasteSheet> createState() => _PasteSheetState();
}

class _PasteSheetState extends State<_PasteSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = parseRosterPaste(_text.text);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom < 0 ? 0 : bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(GuidanceStrings.pasteTitle, style: AppTextStyles.heading),
              const SizedBox(height: AppSizes.spacing4),
              Text(GuidanceStrings.pasteHint, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
              const SizedBox(height: AppSizes.spacing12),
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 6,
                maxLines: 12,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.spacing8),
              Text(GuidanceStrings.pastePreview(names.length), style: AppTextStyles.bodyS),
              const SizedBox(height: AppSizes.spacing12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.goldFill, foregroundColor: AppColors.onGold),
                onPressed: names.isEmpty ? null : () => Navigator.pop(context, names),
                child: const Text(GuidanceStrings.pasteConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 삭제한 기록 화면을 구현한다**

`lib/features/guidance/presentation/screens/guidance_trash_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../providers/guidance_providers.dart';

/// 탭 안의 휴지통. 공용 휴지통에 두지 않는다 — 거기는 잠금이 없다.
/// 30일 자동 정리 대상도 아니다(근거 자료가 조용히 사라지면 안 된다).
class GuidanceTrashScreen extends ConsumerWidget {
  const GuidanceTrashScreen({super.key});

  static Key restoreKey(int id) => Key('g_trash_restore_$id');
  static Key purgeKey(int id) => Key('g_trash_purge_$id');

  Future<void> _purge(BuildContext context, WidgetRef ref, int id) async {
    final ok = await ConfirmDialog.show(
      context: context,
      useRootNavigator: false,
      title: GuidanceStrings.purgeTitle,
      message: GuidanceStrings.purgeMessage,
      confirmLabel: GuidanceStrings.purge,
      confirmColor: AppColors.error,
    );
    if (ok) await ref.read(guidanceActionsProvider).permanentDelete(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleted = ref.watch(guidanceDeletedRecordsProvider).valueOrNull ?? const <GuidanceRecord>[];
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(GuidanceStrings.trashTitle, style: AppTextStyles.heading)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.spacing16),
            child: Text(GuidanceStrings.trashIntro, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
          ),
          if (deleted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSizes.spacing32),
              child: Center(child: Text(GuidanceStrings.trashEmpty, style: AppTextStyles.bodyM)),
            ),
          for (final r in deleted)
            ListTile(
              title: Text(r.content.title),
              subtitle: Text(GuidanceStrings.deletedAt(formatStamp(r.deletedAt ?? r.createdAt, now: now))),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    key: restoreKey(r.id),
                    onPressed: () => ref.read(guidanceActionsProvider).restore(r.id),
                    child: const Text(GuidanceStrings.restore),
                  ),
                  IconButton(
                    key: purgeKey(r.id),
                    tooltip: GuidanceStrings.purge,
                    icon: Icon(Icons.delete_forever, color: AppColors.error),
                    onPressed: () => _purge(context, ref, r.id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 라우트를 더한다**

지도 기록 `GoRoute`의 `routes` 목록 끝에(`record/:id` 뒤):

```dart
                GoRoute(
                  path: 'people',
                  builder: (context, state) => const GuidancePeopleScreen(),
                ),
                GoRoute(
                  path: 'trash',
                  builder: (context, state) => const GuidanceTrashScreen(),
                ),
```

- [ ] **Step 7: 통과를 확인한다**

Run: `flutter test test/features/guidance/ && flutter analyze`
Expected: 전부 PASS, `No issues found!`

- [ ] **Step 8: 커밋**

```bash
git add lib/features/guidance lib/core test/features/guidance
git commit -m "feat(guidance): 명단 관리(붙여넣기·보관)와 탭 안의 삭제한 기록

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017CsGY18wT1wE3iKefCxJo7"
```

---

### Task 10: 분리 가드 · 개인정보처리방침 · 문서 · 런타임 검증

**Files:**
- Create: `test/features/guidance/guidance_isolation_test.dart`
- Modify: `docs/privacy_policy.md`, `CLAUDE.md`, `docs/notes/project-structure.md`
- Test: 위 가드 + 전체 스위트

**Interfaces:**
- Consumes: 앞 Task 전부.
- Produces: 없음(검증·문서).

- [ ] **Step 1: 분리 가드를 쓴다**

`test/features/guidance/guidance_isolation_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 지도 기록은 잠금 안에만 있다. 잠금이 없는 화면·밖으로 나가는 경로가 이 기록을 읽으면
/// 잠금이 무의미해진다 — 그 코드들에 `guidance`라는 낱말 자체가 없어야 한다.
void main() {
  const forbidden = [
    'lib/features/calendar',
    'lib/features/today',
    'lib/features/notifications',
    'lib/features/google',
    'lib/features/trash',
    'lib/features/schedule',
    'lib/features/import',
    'lib/features/memo',
    'lib/core/app_intents',
    'lib/features/settings/data/schedule_csv_exporter.dart',
  ];

  test('캘린더·오늘·알림·Google·공용 휴지통·내보내기·단축어는 지도 기록을 모른다', () {
    for (final path in forbidden) {
      final entity = FileSystemEntity.typeSync(path);
      final files = entity == FileSystemEntityType.directory
          ? Directory(path).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))
          : [File(path)];
      for (final f in files) {
        expect(f.readAsStringSync().toLowerCase().contains('guidance'), isFalse, reason: f.path);
      }
    }
  });

  test('공용 휴지통의 30일 정리는 지도 기록 저장소를 부르지 않는다', () {
    final src = File('lib/features/trash/presentation/providers/trash_providers.dart').readAsStringSync();
    expect(src.contains('Guidance'), isFalse);
  });
}
```

Run: `flutter test test/features/guidance/guidance_isolation_test.dart`
Expected: PASS. 실패하면 **그 파일에서 지도 기록 참조를 걷어낸다**(가드를 고치지 않는다).

- [ ] **Step 2: 개인정보처리방침을 고친다**

`docs/privacy_policy.md`를 읽고 다음을 반영한다:
- 상단의 시행일·최종 수정일 줄이 있으면 오늘 날짜(2026-10-03)로.
- §2 표에 두 줄 추가(기존 행 뒤):

```markdown
| 지도 기록 명단 | 이름, 구분(학생·보호자·교직원·기타), 소속·관계 메모 | 사용자가 지도 기록 탭에서 입력할 때 | 기기 내 SQLite |
| 지도 기록 | 사건 시각, 제목, 장소, 관련인 이름, 경과·들은 말·판단·조치, 수정 이력, 녹음 파일, 사진 파일 | 사용자가 지도 기록을 저장하거나 녹음·사진을 붙일 때 | 기기 내 SQLite + 앱 전용 폴더(다른 앱에서 보이지 않음) |
```

- §2의 `본 앱은 **위치 정보, 연락처, 사진, 마이크, 카메라 정보를 수집하지 않습니다.**` 문장을 다음으로 바꾼다:

```markdown
본 앱은 **위치 정보, 연락처, 카메라 정보를 수집하지 않습니다.** 마이크와 사진은 사용자가 지도 기록에
녹음하거나 사진을 붙일 때만 사용하며, 그 파일은 기기 안에만 저장되고 **외부로 전송하지 않습니다.**
```

- §4(보유 기간)에 항목 추가:

```markdown
- **지도 기록(기기 내 SQLite·앱 전용 폴더)**: 사용자가 `삭제한 기록`에서 영구 삭제하거나, 설정 →
  "전체 데이터 초기화" 또는 앱 삭제를 할 때까지 기기에 남습니다. 다른 항목과 달리 **30일 자동
  삭제 대상이 아닙니다**(근거 자료가 사용자 모르게 사라지지 않게 하기 위해서입니다).
```

- §5-4(기기 백업)에 문단 추가:

```markdown
지도 기록의 **녹음·사진 파일은 Android 클라우드 백업에 포함되지 않습니다**(앱당 백업 용량 상한을
넘기면 일정 데이터까지 백업되지 않기 때문입니다). 글 기록과 명단은 백업됩니다. iOS에서는 기기
백업(iCloud 백업)에 함께 포함됩니다.
```

- §6(안전성 확보 조치)에 항목 추가:

```markdown
- **지도 기록 잠금**: 지도 기록 탭은 들어갈 때마다 기기 인증(Face ID·지문·기기 암호)을 거칩니다.
  다른 탭으로 옮기거나 앱을 떠나면 다시 잠기고, Android에서는 이 탭이 보이는 동안 화면 캡처와
  최근 앱 미리보기를 막습니다.
```

Run: `flutter test test/deploy/`
Expected: PASS(방침 URL·출처 가드가 있다면 통과해야 한다).

- [ ] **Step 3: CLAUDE.md와 구조 문서를 고친다**

`CLAUDE.md`:
- `## 핵심 기능` 끝에 15번:

```markdown
15. **지도 기록(선택 탭)** — 학교 단계의 생활지도·교육활동 침해를 남겨 두는 곳. 기본 꺼짐
   (`설정 › 기능 관리 › 지도 기록`). 들어갈 때마다 기기 인증 잠금. 저장할 때마다 **판이 쌓이고**
   이전 판은 고칠 수 없다. 녹음(앱 안·파일 가져오기)·사진을 원본 그대로(SHA-256) 붙인다.
   관련인에게 가해·피해 역할을 붙이지 않는다. 캘린더·오늘·내보내기·공용 휴지통과 연결되지 않는다.
```

- 기술 스택 표에 행 추가: `| 잠금·녹음 | local_auth 3.0.2 · record 7.1.1 · just_audio 0.10.6 · wakelock_plus 1.3.3 · crypto 3.0.7 | 지도 기록 전용 |`
- 로컬 DB 행을 `스키마 v10 (8 테이블, …, guidance_*)`로.
- 라우팅 행에 `/guidance`(중첩 셸 — 잠금 게이트) 추가.
- 테스트 수를 이번 `flutter test` 실측값으로 바꾸고 직전 값 `1298`과 늘어난 이유를 한 줄로.
- `## 데이터베이스 스키마` 제목을 `(v10)`으로, 그 아래 `### guidance_*` 절(스펙의 표를 줄여 칸 이름만)과 마이그레이션 목록에 `v9→v10(guidance 테이블 넷 생성)`.
- `## 주요 설계 결정` 끝에 `### 지도 기록 (선택 탭)` 절 — 다음 급소를 적는다(스펙 링크 포함):
  - 판은 추가만(가드) · 기록 시각 불변 · 같은 내용이면 판 없음
  - 잠금은 중첩 셸 builder — `go`로 탭을 옮기면 dispose되어 다시 잠긴다
  - **`SystemSheetGuard`**: Face ID·고르기·권한 창은 앱을 비활성으로 만든다. 감싸지 않으면 무한 인증·사진 고르고 오면 잠김
  - 대화상자는 `useRootNavigator: false`(가드) — 루트에 뜨면 덮개 위에 남는다
  - 첨부는 원본 그대로 + SHA-256, 빼기는 `removed_at`만
  - Android 클라우드 백업에서 첨부 제외(25MB 상한) — 기기 간 이전은 포함
  - 공용 휴지통·30일 정리·분리 대상 코드는 `guidance`를 모른다(가드)
  - 녹음은 화면을 켜 둔다(백그라운드 녹음 없음) — 앱을 떠나면 그때까지 저장
  - `MainActivity`가 `FlutterFragmentActivity`, LaunchTheme가 AppCompat(local_auth)

`docs/notes/project-structure.md`의 `features/` 트리에 `guidance/`(data·domain·presentation(lock·recording·screens·widgets·providers)) 한 덩어리를 파일별 한 줄 설명과 함께 더한다.

- [ ] **Step 4: 전체 검증**

Run: `flutter analyze && flutter test 2>&1 | tail -3`
Expected: `No issues found!`, `All tests passed!` — 통과한 수를 CLAUDE.md 테스트 칸에 적는다.

Run: `bash .claude/hooks/test_hooks.sh`
Expected: 전부 통과.

- [ ] **Step 5: iOS 시뮬레이터 런타임 확인**

메모리의 `sim_ios27_xcodebuild_mcp`·`xcode27_build_env`를 따른다(iOS 27 iPhone 17, xcodebuild MCP `snapshot_ui`/`tap`).

1. **업그레이드**: `git stash` 없이 별도 워크트리에서 main(`5cb12b9` 이후, v9)을 빌드·설치하고 일정·쪽지를 하나씩 넣는다 → 이 브랜치를 덮어 설치 → 일정·쪽지가 그대로이고 `설정 › 기능 관리`에 `지도 기록`이 있는지.
2. 기능 관리에서 켠다 → 탭 바에 `지도 기록`.
3. 탭에 들어간다 → 잠금 덮개. 시뮬레이터는 기본으로 Face ID 미등록·암호 없음이라 **`기기 암호가 설정되어 있지 않아요` + `잠금 없이 열기`** 경로가 보여야 한다. 연다.
4. 명단 `여러 명 붙여넣기`로 셋 넣기 → 새 기록: 구분 `교육활동 침해`, 관련인 하나는 명단, 하나는 명단 밖(명단에도 추가 해제), 경과·들은 말·판단·조치 → 저장 → 목록 행 확인.
5. 사진 가져오기: `xcrun simctl addmedia <udid> <png>`로 사진을 넣고 고른다 → 첨부 타일, ⓘ에서 SHA-256 확인.
6. 녹음: `녹음하기` → 마이크 권한 허용 → 몇 초 뒤 멈춤 → 첨부에 녹음, 재생 버튼으로 재생되는지.
7. 기록 고치기 → 경과 한 줄 추가 저장 → `수정 1회` 링크 → 수정 이력에 판 둘, 처음 원문, `바뀐 칸: 경과`.
8. 다른 탭으로 갔다 돌아오기 → 잠금 덮개.
9. 홈으로 나갔다 앱 전환기에서 미리보기를 캡처 → 기록 내용이 보이지 않는지(덮개). **보이면** 멈추고 보고한다 — 스펙대로 SceneDelegate 가림막으로 바꿀지 사용자에게 묻는다.
10. 삭제 → `삭제한 기록` → 되살리기 / 영구 삭제.
11. 설정 › 전체 데이터 초기화 확인 창에 `지도 기록 N건과 첨부 N개도 지워집니다.`

볼 화면은 스크린샷으로 남겨 사용자에게 올린다(메모리 `feedback_sim_is_mine_testflight_is_users`).

- [ ] **Step 6: Android 에뮬레이터 확인**

메모리 `android_api36_emulator`(AVD `api36_pixel7`)를 따른다.

1. 설치·실행 → 지도 기록 켜기 → 잠금(에뮬레이터는 PIN 없음 → `잠금 없이 열기`). 설정에서 PIN을 만들고 다시 들어가 **기기 인증 창이 뜨고 크래시가 없는지**(FragmentActivity·AppCompat 확인).
2. 지도 기록 탭에서 `adb exec-out screencap -p > s.png` → 검은 화면(FLAG_SECURE). 다른 탭에서는 정상 화면.
3. 사진 하나 붙인 뒤 `adb shell run-as com.planroutine.app ls files/guidance` → 파일이 있는지(백업 제외 경로와 같은 곳인지).
4. **CSV 공유 재확인**(MainActivity 부모 변경): CLAUDE.md `Android 공유·열기` 절의 방법대로 `content://` + `--grant-read-uri-permission`으로 **cold-start·running 둘 다** `/import`에 도착하는지.

- [ ] **Step 7: 실기기에서만 확인할 것을 정리한다**

보고에 적는다(사용자 몫): 실제 Face ID·지문 해제, 실제 마이크 음질, 녹음 중 전화 수신, 아이폰 메모 앱의 통화 녹음 가져오기 경로(문구가 맞는지), 앱 전환기 가림(실기기).

- [ ] **Step 8: 커밋**

```bash
git add test/features/guidance/guidance_isolation_test.dart docs/privacy_policy.md CLAUDE.md docs/notes/project-structure.md
git commit -m "docs(guidance): 분리 가드·개인정보처리방침·CLAUDE.md에 지도 기록 반영

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017CsGY18wT1wE3iKefCxJo7"
```
