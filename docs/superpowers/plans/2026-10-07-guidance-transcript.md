# 지도 기록 글로 보기(참고용 전사) · 녹음만 공유 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 지도 기록의 녹음을 iOS 기기 안에서 참고용 글로 바꿔 보여 주고(저장 안 함), 내보내기 시트에서 녹음만 원본 그대로 보낼 수 있게 한다.

**Architecture:** iOS 26 `SpeechAnalyzer`/`SpeechTranscriber`를 앱 타깃의 Swift 파일 하나(`Transcriber.swift`)가 부르고, MethodChannel(지원 여부)과 EventChannel(문단 흘려 보내기)로 Dart에 넘긴다. 표시 규칙(글 없음 구간·복사 형식·재생 중 문단)은 Dart 순수 함수가 진다. 녹음만 공유는 `ExportKind.audioOnly` + 원본 파일을 임시 폴더로 복사해 공유하는 별도 경로다.

**Tech Stack:** Flutter 3.44.8 / Dart 3.12.2, Riverpod, GoRouter, freezed 3, just_audio 0.10.6, share_plus, file_picker, Swift(Speech · AVFoundation, iOS 26 SDK).

**Spec:** `docs/superpowers/specs/2026-10-07-guidance-transcript-design.md` — 실행자는 이 계획과 함께 반드시 읽는다.

## Global Constraints

- iOS 배포 타깃 **16.0 유지**. 전사 코드는 전부 `if #available(iOS 26.0, *)` / `@available(iOS 26.0, *)` 안에 둔다.
- 안드로이드에서는 `글로 보기`를 숨긴다(채널을 부르지 않고 false). 플랫폼 분기는 `dart:io`의 `Platform.isAndroid` + 주입점(리포 규칙, `defaultTargetPlatform` 금지).
- 전사문은 **어디에도 저장하지 않는다** — DB·prefs·파일 모두. DB 스키마 v10 그대로.
- 전사 로케일은 `ko-KR` 고정.
- 글 없음 구간 기준: **8초(8000ms) 이상**.
- 문구는 `GuidanceStrings`에 둔다(하드코딩 금지). 스낵바에 **기록·전사 내용을 넣지 않는다**(상수 문구만).
- 녹음만 파일 이름: `지도기록_<yyyyMMdd-HHmm>_<NN><ext>`, 제목 미포함, `NN`은 고른 녹음 사이 순번.
- 녹음만 공유는 원본을 **메모리에 읽지 않고** `File.copy`로 임시 폴더(`guidance_export/`)에 복사 후 공유, 끝나면 지운다. 예외: 안드로이드 `기기에 저장`(SAF가 바이트를 요구, 1개일 때만).
- 대화상자는 `useRootNavigator: false`(지도 기록 가드). 직접 만든 터치 영역은 `ButtonSemantics`, 아이콘 버튼 이름은 `Icon(semanticLabel:)`(tooltip 금지).
- 색은 `AppColors` 토큰만. 골드 채움 = `goldFill` + `onGold`.
- 기존 테스트 삭제 금지. 각 작업 끝에 `flutter analyze`가 깨끗해야 한다.

## Review Focus

1. **1시간이 넘는 녹음** — 시각이 `1:02:15`처럼 시 단위로 나와야 한다(`MM:SS`가 `62:15`가 되면 안 됨). → Task 2 `formatTranscriptTime` 테스트.
2. **전사 도중 화면을 떠남** — 구독이 끊기고(Swift 취소), dispose 뒤 `setState` 예외가 없어야 한다. → Task 6 "전사 중 뒤로 가면 구독을 끊는다" 테스트.
3. **엔진이 빈 글·공백 문단을 줌 / 순서가 뒤섞여 옴** — 빈 카드가 생기거나 글 없음 계산이 음수가 되면 안 된다. → Task 2 테스트.
4. **첨부 정보가 없거나(durationMs null, 가져온 파일) 파일이 사라짐** — 진행 막대가 0으로 나누지 않고, 파일이 없으면 `파일을 찾을 수 없어요`. → Task 6 테스트 둘.
5. **녹음만 복사 도중 실패(파일이 시트를 연 뒤 사라짐)** — 시트 안 실패 줄 + 임시 폴더에 사본이 남지 않아야 한다. → Task 8 "복사 실패 시 사본을 남기지 않는다" 테스트.

---

## File Structure

| 파일 | 책임 |
|---|---|
| Create `lib/features/guidance/domain/transcript.dart` | `TranscriptSegment`(freezed) · `TranscriptItem`(문단/글 없음) · `buildTranscriptView` · `activeSegmentIndex` · `formatTranscriptTime` · `formatTranscriptForCopy` (순수) |
| Create `lib/features/guidance/data/transcription_service.dart` | `TranscriptionService` 인터페이스 · `TranscriptEvent` · `TranscriptionException`/`TranscriptFailure` · `ChannelTranscriptionService` · 채널 이름 상수 `TranscriberContract` |
| Modify `lib/features/guidance/presentation/providers/guidance_providers.dart` | `transcriptionServiceProvider` · `transcriptAvailableProvider` |
| Create `ios/Runner/Transcriber.swift` | 지원 여부 + 파일 전사(EventChannel 스트림 핸들러) |
| Modify `ios/Runner/AppDelegate.swift` | 채널 둘 배선 |
| Modify `ios/Runner.xcodeproj/project.pbxproj` | `Transcriber.swift` 앱 타깃 등록 |
| Modify `lib/features/guidance/presentation/widgets/audio_playback.dart` | `playFrom(path, at)` 추가 |
| Create `lib/features/guidance/presentation/screens/guidance_transcript_screen.dart` | 글로 보기 화면(B안) |
| Modify `lib/core/router/app_router.dart` (+ `AppRoutes`) | `/guidance/record/:id/transcript/:attachmentId` |
| Modify `lib/features/guidance/presentation/widgets/attachment_tile.dart` | `onTranscribe` 콜백 → `글로 보기 · 참고용` 버튼 |
| Modify `lib/features/guidance/presentation/screens/guidance_detail_screen.dart` | 지원·녹음일 때 `onTranscribe` 전달 |
| Modify `lib/features/guidance/domain/guidance_export.dart` | `ExportKind.audioOnly` · `buildAudioOnlyFiles` |
| Modify `lib/features/guidance/data/guidance_exporter.dart` | `copyAudioForShare` |
| Modify `lib/features/guidance/presentation/widgets/guidance_export_sheet.dart` | `녹음만` 선택지·공유·저장 |
| Modify `lib/core/constants/strings/guidance_strings.dart` | 새 문구 |
| Tests | `test/features/guidance/domain/transcript_test.dart` · `test/features/guidance/data/transcription_service_test.dart` · `test/features/guidance/transcriber_wiring_test.dart` · `test/features/guidance/presentation/guidance_transcript_screen_test.dart` · 기존 `attachment_tile_test.dart`·`guidance_detail_screen_test.dart`·`guidance_export_test.dart`·`guidance_exporter_test.dart`·`guidance_export_sheet_test.dart`에 추가 |

---

### Task 1: 시뮬레이터에서 SpeechTranscriber가 도는지 확인 (버리는 코드)

이 결과가 Task 9의 검증 방법을 정한다. **리포에 코드를 남기지 않는다.**

**Files:**
- Throwaway: 작업용 임시 폴더(scratchpad)의 `stt/transcribe.swift`(이미 Mac에서 쓴 스크립트), `stt/dialog.aac`
- Modify: `docs/superpowers/specs/2026-10-07-guidance-transcript-design.md` (검증 절에 결과 한 줄)

**Interfaces:** 없음.

- [ ] **Step 1: 시뮬레이터용으로 컴파일**

scratchpad의 `stt/` 폴더에서:
```bash
xcrun -sdk iphonesimulator swiftc -parse-as-library \
  -target arm64-apple-ios26.0-simulator transcribe.swift -o transcribe-sim
```
Expected: 오류 없이 `transcribe-sim` 생성. (스크립트가 없으면 스펙 "Mac 실측"의 코드로 다시 쓴다 — SpeechTranscriber(locale: ko-KR, attributeOptions: [.audioTimeRange]) + AssetInventory + analyzeSequence.)

- [ ] **Step 2: 부팅된 시뮬레이터에서 실행**

```bash
xcrun simctl list devices booted   # 없으면: xcrun simctl boot "iPhone 17"
xcrun simctl spawn booted "$PWD/transcribe-sim" "$PWD/dialog.aac"
```
Expected 둘 중 하나:
- 문단이 출력됨 → 시뮬레이터에서 전사 확인 가능.
- `isAvailable: false` / `ko-KR 미지원` / 오류 → 시뮬레이터에서는 미지원 경로만 확인 가능.

- [ ] **Step 3: 결과를 스펙에 기록하고 커밋**

스펙 `## 검증`의 ⚠️ 줄 아래에 한 줄 추가: `- 확인 결과(2026-10-07, iOS <버전> 시뮬레이터): <문단이 나왔다 | isAvailable false — 전사 결과는 실기기 몫>.`
```bash
git add docs/superpowers/specs/2026-10-07-guidance-transcript-design.md
git commit -m "docs(guidance): SpeechTranscriber 시뮬레이터 동작 여부 기록"
```

---

### Task 2: 전사 표시 규칙 (순수 함수)

**Files:**
- Create: `lib/features/guidance/domain/transcript.dart`
- Generated: `lib/features/guidance/domain/transcript.freezed.dart`
- Test: `test/features/guidance/domain/transcript_test.dart`

**Interfaces:**
- Produces:
  - `TranscriptSegment({required int startMs, required int endMs, required String text})` (freezed)
  - `sealed class TranscriptItem` / `TranscriptParagraph(TranscriptSegment segment)` / `TranscriptGap({required int startMs, required int lengthMs})`
  - `List<TranscriptItem> buildTranscriptView(List<TranscriptSegment> segments, {int gapMs = transcriptGapMs})`
  - `const transcriptGapMs = 8000;`
  - `int? activeSegmentIndex(List<TranscriptSegment> visible, int positionMs)` — `visible`은 `cleanSegments` 결과 기준 인덱스
  - `List<TranscriptSegment> cleanSegments(List<TranscriptSegment> segments)` — 빈 글 제거 + 시작 시각 정렬
  - `String formatTranscriptTime(int ms)`
  - `String formatTranscriptForCopy(List<TranscriptSegment> segments)`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/domain/transcript.dart';

TranscriptSegment seg(int s, int e, [String t = '말']) =>
    TranscriptSegment(startMs: s, endMs: e, text: t);

void main() {
  group('formatTranscriptTime', () {
    test('한 시간 미만은 MM:SS', () {
      expect(formatTranscriptTime(0), '00:00');
      expect(formatTranscriptTime(75 * 1000 + 900), '01:15');
    });
    test('한 시간 이상은 H:MM:SS — 62:15가 되면 안 된다', () {
      expect(formatTranscriptTime((3600 + 135) * 1000), '1:02:15');
    });
  });

  group('cleanSegments', () {
    test('빈 글·공백 글을 버리고 시작 시각 순으로 놓는다', () {
      final out = cleanSegments([seg(9000, 12000, 'B'), seg(0, 3000, '  '), seg(1000, 4000, 'A')]);
      expect(out.map((s) => s.text), ['A', 'B']);
    });
  });

  group('buildTranscriptView', () {
    test('사이가 8초 이상이면 글 없음 줄을 끼운다', () {
      final items = buildTranscriptView([seg(0, 5000), seg(13000, 15000)]);
      expect(items, hasLength(3));
      final gap = items[1] as TranscriptGap;
      expect(gap.startMs, 5000);
      expect(gap.lengthMs, 8000);
    });
    test('8초 미만이면 끼우지 않는다', () {
      expect(buildTranscriptView([seg(0, 5000), seg(12999, 15000)]).whereType<TranscriptGap>(), isEmpty);
    });
    test('녹음 맨 앞이 8초 이상 비면 처음에 글 없음 줄', () {
      final items = buildTranscriptView([seg(9000, 10000)]);
      expect(items.first, isA<TranscriptGap>());
      expect((items.first as TranscriptGap).startMs, 0);
    });
    test('겹치거나 뒤섞여 와도 음수 길이가 생기지 않는다', () {
      final items = buildTranscriptView([seg(4000, 9000), seg(0, 6000)]);
      expect(items.whereType<TranscriptGap>(), isEmpty);
      expect(items.whereType<TranscriptParagraph>(), hasLength(2));
    });
    test('문단이 0개면 빈 목록', () {
      expect(buildTranscriptView(const []), isEmpty);
    });
  });

  group('activeSegmentIndex', () {
    final segs = [seg(0, 5000), seg(15000, 20000)];
    test('시작 전·글 없음 구간 안·끝 뒤는 null', () {
      expect(activeSegmentIndex(segs, 9000), isNull);
      expect(activeSegmentIndex(segs, 25000), isNull);
    });
    test('문단 안이면 그 인덱스', () {
      expect(activeSegmentIndex(segs, 0), 0);
      expect(activeSegmentIndex(segs, 16000), 1);
    });
  });

  test('전체 복사는 [시각] 글을 빈 줄로 잇는다', () {
    expect(
      formatTranscriptForCopy([seg(15000, 16000, '둘째'), seg(0, 1000, '첫째'), seg(2000, 3000, ' ')]),
      '[00:00] 첫째\n\n[00:15] 둘째',
    );
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/guidance/domain/transcript_test.dart`
Expected: FAIL — `transcript.dart` 없음.

- [ ] **Step 3: 구현**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transcript.freezed.dart';

/// 기기가 받아 적은 문단 하나. **저장하지 않는다** — 화면이 떠 있는 동안만 산다.
@freezed
abstract class TranscriptSegment with _$TranscriptSegment {
  const factory TranscriptSegment({
    required int startMs,
    required int endMs,
    required String text,
  }) = _TranscriptSegment;
}

/// 이보다 길게 글이 없으면 "글 없음" 줄을 끼운다 — 작게 말한 학생의 말이 대개 여기 빠진다(스펙 실측).
const transcriptGapMs = 8000;

sealed class TranscriptItem {
  const TranscriptItem();
}

class TranscriptParagraph extends TranscriptItem {
  const TranscriptParagraph(this.segment);
  final TranscriptSegment segment;
}

class TranscriptGap extends TranscriptItem {
  const TranscriptGap({required this.startMs, required this.lengthMs});
  final int startMs;
  final int lengthMs;
}

/// 빈 글을 버리고 시작 시각 순으로 놓는다. 화면·복사·재생 표시가 모두 이 목록을 본다.
List<TranscriptSegment> cleanSegments(List<TranscriptSegment> segments) =>
    [for (final s in segments) if (s.text.trim().isNotEmpty) s]
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

List<TranscriptItem> buildTranscriptView(
  List<TranscriptSegment> segments, {
  int gapMs = transcriptGapMs,
}) {
  final items = <TranscriptItem>[];
  var cursor = 0;
  for (final s in cleanSegments(segments)) {
    if (s.startMs - cursor >= gapMs) {
      items.add(TranscriptGap(startMs: cursor, lengthMs: s.startMs - cursor));
    }
    items.add(TranscriptParagraph(s));
    // 겹치거나 뒤섞여 와도 커서는 뒤로 가지 않는다 — 음수 길이를 막는다.
    if (s.endMs > cursor) cursor = s.endMs;
  }
  return items;
}

int? activeSegmentIndex(List<TranscriptSegment> visible, int positionMs) {
  for (var i = 0; i < visible.length; i++) {
    final s = visible[i];
    if (positionMs >= s.startMs && positionMs < s.endMs) return i;
  }
  return null;
}

String formatTranscriptTime(int ms) {
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String formatTranscriptForCopy(List<TranscriptSegment> segments) => [
  for (final s in cleanSegments(segments)) '[${formatTranscriptTime(s.startMs)}] ${s.text.trim()}',
].join('\n\n');
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/guidance/domain/transcript_test.dart`
Expected: PASS (11건).

- [ ] **Step 5: 커밋**

```bash
git add lib/features/guidance/domain/transcript.dart lib/features/guidance/domain/transcript.freezed.dart test/features/guidance/domain/transcript_test.dart
git commit -m "feat(guidance): 전사 표시 규칙 — 글 없음 구간·재생 중 문단·복사 형식"
```

---

### Task 3: Dart 전사 서비스 + 지원 여부 provider + 문구

**Files:**
- Create: `lib/features/guidance/data/transcription_service.dart`
- Modify: `lib/features/guidance/presentation/providers/guidance_providers.dart`
- Modify: `lib/core/constants/strings/guidance_strings.dart`
- Test: `test/features/guidance/data/transcription_service_test.dart`

**Interfaces:**
- Consumes: `TranscriptSegment` (Task 2)
- Produces:
  - `abstract final class TranscriberContract { static const methodChannel = 'planroutine/transcriber'; static const eventChannel = 'planroutine/transcriber/segments'; static const methodIsAvailable = 'isAvailable'; static const eventPreparing = 'preparing'; static const eventSegment = 'segment'; }`
  - `sealed class TranscriptEvent` / `TranscriptPreparing` / `TranscriptSegmentArrived(TranscriptSegment segment)`
  - `enum TranscriptFailure { modelDownload, fileNotFound, unsupported, other }` + `class TranscriptionException implements Exception { final TranscriptFailure failure; }`
  - `abstract class TranscriptionService { Future<bool> isAvailable(); Stream<TranscriptEvent> transcribe(String path); }`
  - `class ChannelTranscriptionService implements TranscriptionService { ChannelTranscriptionService({bool? isAndroid}); }`
  - `final transcriptionServiceProvider = Provider<TranscriptionService>(...)`
  - `final transcriptAvailableProvider = FutureProvider<bool>(...)` (autoDispose 아님 — 기기 성능은 실행 중 안 바뀐다)
  - 문구(`GuidanceStrings`): `transcribe`, `transcribeTag`, `transcriptTitle`, `transcriptCopyAll`, `transcriptCopy`, `transcriptCopied`, `transcriptNotice`, `transcriptProgress`, `transcriptProgressNotice`, `transcriptPreparing`, `transcriptGap(String from, int seconds)`, `transcriptEmpty`, `transcriptModelFailed`, `transcriptFailed`, `transcriptRetry`, `transcriptPlayFrom(String time)`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/data/transcription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const method = MethodChannel(TranscriberContract.methodChannel);
  const events = EventChannel(TranscriberContract.eventChannel);

  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(events, null);
  });

  test('안드로이드면 채널을 부르지 않고 false', () async {
    var called = false;
    messenger.setMockMethodCallHandler(method, (_) async {
      called = true;
      return true;
    });
    expect(await ChannelTranscriptionService(isAndroid: true).isAvailable(), isFalse);
    expect(called, isFalse);
  });

  test('iOS면 채널 답을 그대로, 채널 오류는 false', () async {
    messenger.setMockMethodCallHandler(method, (_) async => true);
    expect(await ChannelTranscriptionService(isAndroid: false).isAvailable(), isTrue);
    messenger.setMockMethodCallHandler(method, (_) async => throw PlatformException(code: 'x'));
    expect(await ChannelTranscriptionService(isAndroid: false).isAvailable(), isFalse);
  });

  test('이벤트를 준비·문단으로 바꾸고 경로를 인자로 넘긴다', () async {
    Object? gotArgs;
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (args, sink) {
        gotArgs = args;
        sink.success({'type': 'preparing'});
        sink.success({'type': 'segment', 'startMs': 0, 'endMs': 1500, 'text': '안녕'});
        sink.endOfStream();
      }),
    );
    final out = await ChannelTranscriptionService(isAndroid: false).transcribe('/a.aac').toList();
    expect(gotArgs, '/a.aac');
    expect(out.first, isA<TranscriptPreparing>());
    final seg = (out[1] as TranscriptSegmentArrived).segment;
    expect((seg.startMs, seg.endMs, seg.text), (0, 1500, '안녕'));
  });

  test('오류 코드를 실패 종류로 바꾼다', () async {
    for (final (code, failure) in [
      ('modelDownloadFailed', TranscriptFailure.modelDownload),
      ('fileNotFound', TranscriptFailure.fileNotFound),
      ('unsupported', TranscriptFailure.unsupported),
      ('weird', TranscriptFailure.other),
    ]) {
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(onListen: (_, sink) => sink.error(code: code)),
      );
      await expectLater(
        ChannelTranscriptionService(isAndroid: false).transcribe('/a.aac'),
        emitsError(isA<TranscriptionException>().having((e) => e.failure, 'failure', failure)),
      );
    }
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/guidance/data/transcription_service_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 3: 구현**

`lib/features/guidance/data/transcription_service.dart`:
```dart
import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/transcript.dart';

/// Swift(`ios/Runner/Transcriber.swift`)와 맞춰야 하는 이름들. 가드가 양쪽을 대조한다.
abstract final class TranscriberContract {
  static const methodChannel = 'planroutine/transcriber';
  static const eventChannel = 'planroutine/transcriber/segments';
  static const methodIsAvailable = 'isAvailable';
  static const eventPreparing = 'preparing';
  static const eventSegment = 'segment';
}

sealed class TranscriptEvent {
  const TranscriptEvent();
}

/// 한국어 모델을 처음 내려받는 중.
class TranscriptPreparing extends TranscriptEvent {
  const TranscriptPreparing();
}

class TranscriptSegmentArrived extends TranscriptEvent {
  const TranscriptSegmentArrived(this.segment);
  final TranscriptSegment segment;
}

enum TranscriptFailure { modelDownload, fileNotFound, unsupported, other }

class TranscriptionException implements Exception {
  const TranscriptionException(this.failure);
  final TranscriptFailure failure;
}

/// 기기 안 전사. 위젯 테스트에서는 가짜 구현을 끼운다(`AudioPlayback`과 같은 이유).
abstract class TranscriptionService {
  Future<bool> isAvailable();

  /// 구독을 끊으면 기기 쪽 전사도 멈춘다.
  Stream<TranscriptEvent> transcribe(String path);
}

class ChannelTranscriptionService implements TranscriptionService {
  /// [isAndroid] 기본은 `Platform.isAndroid` — `defaultTargetPlatform`은 테스트에서 늘 android다.
  ChannelTranscriptionService({bool? isAndroid}) : _isAndroid = isAndroid ?? Platform.isAndroid;

  final bool _isAndroid;
  static const _method = MethodChannel(TranscriberContract.methodChannel);
  static const _events = EventChannel(TranscriberContract.eventChannel);

  @override
  Future<bool> isAvailable() async {
    if (_isAndroid) return false;
    try {
      return await _method.invokeMethod<bool>(TranscriberContract.methodIsAvailable) ?? false;
    } catch (_) {
      // 채널이 없는 빌드·구버전 iOS 등 — 버튼을 숨기면 된다.
      return false;
    }
  }

  @override
  Stream<TranscriptEvent> transcribe(String path) => _events
      .receiveBroadcastStream(path)
      .handleError(
        (Object e) => throw TranscriptionException(_failureOf(e)),
      )
      .map(_eventOf)
      .where((e) => e != null)
      .cast<TranscriptEvent>();

  static TranscriptEvent? _eventOf(dynamic raw) {
    if (raw is! Map) return null;
    return switch (raw['type']) {
      TranscriberContract.eventPreparing => const TranscriptPreparing(),
      TranscriberContract.eventSegment => TranscriptSegmentArrived(
        TranscriptSegment(
          startMs: (raw['startMs'] as num?)?.toInt() ?? 0,
          endMs: (raw['endMs'] as num?)?.toInt() ?? 0,
          text: raw['text'] as String? ?? '',
        ),
      ),
      _ => null,
    };
  }

  static TranscriptFailure _failureOf(Object e) => switch (e is PlatformException ? e.code : null) {
    'modelDownloadFailed' => TranscriptFailure.modelDownload,
    'fileNotFound' => TranscriptFailure.fileNotFound,
    'unsupported' => TranscriptFailure.unsupported,
    _ => TranscriptFailure.other,
  };
}
```

`guidance_providers.dart` 끝에 추가(import `../../data/transcription_service.dart`):
```dart
final transcriptionServiceProvider = Provider<TranscriptionService>(
  (ref) => ChannelTranscriptionService(),
);

/// 이 기기에서 `글로 보기`를 보일지. 기기 성능은 실행 중 바뀌지 않으므로 한 번만 묻는다.
final transcriptAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(transcriptionServiceProvider).isAvailable(),
);
```

`guidance_strings.dart`의 `GuidanceStrings`에 추가(내보내기 문구 근처):
```dart
  // 글로 보기(참고용 전사)
  static const transcribe = '글로 보기';
  static const transcribeTag = '참고용';
  static const transcriptTitle = '글로 보기';
  static const transcriptCopyAll = '전체 복사';
  static const transcriptCopy = '복사';
  static const transcriptCopied = '복사했어요';
  static const transcriptNotice = '작은 목소리는 빠지거나 틀릴 수 있어요. 기록에 옮기기 전에 들어 보세요.';
  static const transcriptProgress = '받아 적는 중…';
  static const transcriptProgressNotice = '이 화면을 닫으면 멈춰요. 녹음은 휴대폰 밖으로 나가지 않아요.';
  static const transcriptPreparing = '한국어 음성 인식 모델을 준비하는 중이에요. 처음 한 번 Apple에서 내려받아요.';
  static String transcriptGap(String from, int seconds) => '$from부터 $seconds초 동안 글이 없어요 · 들어 보기';
  static const transcriptEmpty = '받아 적을 말소리를 찾지 못했어요';
  static const transcriptModelFailed = '처음 한 번은 인터넷 연결이 필요해요';
  static const transcriptFailed = '글로 바꾸지 못했어요';
  static const transcriptRetry = '다시 시도';
  static String transcriptPlayFrom(String time) => '$time부터 재생';
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/guidance/data/transcription_service_test.dart && flutter analyze`
Expected: PASS (4건), analyze 깨끗.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/guidance/data/transcription_service.dart lib/features/guidance/presentation/providers/guidance_providers.dart lib/core/constants/strings/guidance_strings.dart test/features/guidance/data/transcription_service_test.dart
git commit -m "feat(guidance): 전사 채널 서비스와 지원 여부 provider"
```

---

### Task 4: Swift 전사기 + 채널 배선 + 가드

**Files:**
- Create: `ios/Runner/Transcriber.swift`
- Modify: `ios/Runner/AppDelegate.swift` (`didInitializeImplicitFlutterEngine` 끝)
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Test: `test/features/guidance/transcriber_wiring_test.dart`

**Interfaces:**
- Consumes: `TranscriberContract` 상수 값(Task 3) — Swift 쪽에 같은 문자열.
- Produces: 채널 `planroutine/transcriber`(`isAvailable` → Bool) · 이벤트 채널 `planroutine/transcriber/segments`(인자 = 파일 경로, 이벤트 `{type: preparing}` / `{type: segment, startMs, endMs, text}`, 오류 코드 `modelDownloadFailed`·`fileNotFound`·`unsupported`·`failed`).

- [ ] **Step 1: 실패하는 가드 작성**

```dart
// 글로 보기(전사) 배선 가드. Swift는 위젯 테스트로 못 밟으므로 소스를 읽는다
// (`app_intents_wiring_test.dart`와 같은 방법). 실제 동작은 시뮬레이터·실기기의 몫이다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/data/transcription_service.dart';

String _read(String p) => File(p).readAsStringSync();

/// 주석을 걷어낸 코드 — 스캐너는 낱말의 언급과 사용을 구별하지 못한다(리포 함정).
String _codeOnly(String src) => src
    .split('\n')
    .map((l) {
      final i = l.indexOf('//');
      return i < 0 ? l : l.substring(0, i);
    })
    .join('\n');

void main() {
  final swift = _codeOnly(_read('ios/Runner/Transcriber.swift'));
  final delegate = _codeOnly(_read('ios/Runner/AppDelegate.swift'));

  test('채널·이벤트 이름이 Swift와 Dart에서 같다', () {
    for (final name in [
      TranscriberContract.methodChannel,
      TranscriberContract.eventChannel,
      TranscriberContract.methodIsAvailable,
      TranscriberContract.eventPreparing,
      TranscriberContract.eventSegment,
    ]) {
      expect(swift, contains('"$name"'), reason: name);
    }
  });

  test('Dart가 아는 오류 코드를 Swift가 그대로 쓴다', () {
    for (final code in ['modelDownloadFailed', 'fileNotFound', 'unsupported']) {
      expect(swift, contains('"$code"'), reason: code);
    }
  });

  test('전사 API는 iOS 26 분기 안에만 있다 — 배포 타깃 16.0을 유지한다', () {
    expect(swift, contains('@available(iOS 26.0, *)'));
    expect(swift, contains('#available(iOS 26.0, *)'));
  });

  test('AppDelegate가 두 채널을 엔진 초기화 자리에서 잡는다', () {
    final start = delegate.indexOf('func didInitializeImplicitFlutterEngine');
    expect(start, greaterThanOrEqualTo(0));
    expect(delegate.substring(start), contains('TranscriberChannels.register'));
  });

  test('Transcriber.swift가 앱 타깃 빌드에 들어 있다', () {
    final pbx = _read('ios/Runner.xcodeproj/project.pbxproj');
    expect(RegExp(r'Transcriber\.swift in Sources').allMatches(pbx).length, 2,
        reason: 'PBXBuildFile 1 + Sources 단계 1');
  });

  test('Swift에 저장 경로가 없다 — 전사문은 저장하지 않는다', () {
    for (final banned in ['UserDefaults', 'write(to', 'FileManager.default.createFile']) {
      expect(swift, isNot(contains(banned)), reason: banned);
    }
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/guidance/transcriber_wiring_test.dart`
Expected: FAIL — `Transcriber.swift` 없음.

- [ ] **Step 3: Swift 작성**

`ios/Runner/Transcriber.swift`:
```swift
import AVFoundation
import Flutter
import Foundation
import Speech

/// 지도 기록 '글로 보기' — 기기 안 전사(iOS 26+). 녹음은 기기 밖으로 나가지 않는다.
/// 표시 규칙(글 없음 구간·복사 형식)은 Dart가 진다. 여기는 엔진 결과를 그대로 넘긴다.
/// 이름은 `TranscriberContract`(Dart)와 같아야 한다 — `transcriber_wiring_test.dart`가 대조한다.
enum TranscriberChannels {
  static let method = "planroutine/transcriber"
  static let events = "planroutine/transcriber/segments"
  static let isAvailable = "isAvailable"
  static let preparing = "preparing"
  static let segment = "segment"

  private static let handler = TranscriberStreamHandler()

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: method, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == isAvailable else {
        result(FlutterMethodNotImplemented)
        return
      }
      if #available(iOS 26.0, *) {
        Task {
          let ok = await KoreanTranscriber.isAvailable()
          DispatchQueue.main.async { result(ok) }
        }
      } else {
        result(false)
      }
    }
    FlutterEventChannel(name: events, binaryMessenger: messenger).setStreamHandler(handler)
  }
}

final class TranscriberStreamHandler: NSObject, FlutterStreamHandler {
  private var task: Task<Void, Never>?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard let path = arguments as? String else {
      return FlutterError(code: "failed", message: nil, details: nil)
    }
    guard #available(iOS 26.0, *) else {
      return FlutterError(code: "unsupported", message: nil, details: nil)
    }
    task?.cancel()
    task = Task { await KoreanTranscriber.run(path: path, sink: events) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    // 화면을 떠나면 Dart가 구독을 끊는다 → 전사를 멈춘다.
    task?.cancel()
    task = nil
    return nil
  }
}

@available(iOS 26.0, *)
enum KoreanTranscriber {
  private static let wanted = Locale(identifier: "ko-KR")

  static func isAvailable() async -> Bool {
    guard SpeechTranscriber.isAvailable else { return false }
    return await SpeechTranscriber.supportedLocale(equivalentTo: wanted) != nil
  }

  static func run(path: String, sink: @escaping FlutterEventSink) async {
    // 취소된 뒤에는 아무것도 보내지 않는다. 메시지에 경로·내용을 넣지 않는다.
    func send(_ value: Any) {
      if Task.isCancelled { return }
      DispatchQueue.main.async { sink(value) }
    }
    func fail(_ code: String) { send(FlutterError(code: code, message: nil, details: nil)) }

    guard FileManager.default.fileExists(atPath: path) else { return fail("fileNotFound") }
    guard SpeechTranscriber.isAvailable,
          let locale = await SpeechTranscriber.supportedLocale(equivalentTo: wanted)
    else { return fail("unsupported") }

    let transcriber = SpeechTranscriber(
      locale: locale,
      transcriptionOptions: [],
      reportingOptions: [],  // 확정 결과만
      attributeOptions: [.audioTimeRange]
    )
    do {
      if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        send(["type": TranscriberChannels.preparing])
        do {
          try await request.downloadAndInstall()
        } catch {
          return fail("modelDownloadFailed")
        }
      }
      let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
      let analyzer = SpeechAnalyzer(modules: [transcriber])
      let collector = Task {
        for try await result in transcriber.results {
          send([
            "type": TranscriberChannels.segment,
            "startMs": Int(result.range.start.seconds * 1000),
            "endMs": Int(result.range.end.seconds * 1000),
            "text": String(result.text.characters),
          ])
        }
      }
      try await withTaskCancellationHandler {
        if let last = try await analyzer.analyzeSequence(from: file) {
          try await analyzer.finalizeAndFinish(through: last)
        } else {
          await analyzer.cancelAndFinishNow()
        }
        try await collector.value
      } onCancel: {
        collector.cancel()
        Task { await analyzer.cancelAndFinishNow() }
      }
      send(FlutterEndOfEventStream)
    } catch is CancellationError {
      return
    } catch {
      fail("failed")
    }
  }
}
```

- [ ] **Step 4: AppDelegate 배선**

`ios/Runner/AppDelegate.swift`의 `didInitializeImplicitFlutterEngine` 마지막 `}` 바로 앞(단축어 블록 뒤)에 추가:
```swift
    // 지도 기록 '글로 보기'(전사). 다른 채널과 같은 자리에서 잡는다.
    let transcriberRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "PlanRoutineTranscriber")
    if let transcriberMessenger = transcriberRegistrar?.messenger() {
      TranscriberChannels.register(messenger: transcriberMessenger)
    }
```

- [ ] **Step 5: pbxproj 등록**

`PlanRoutineIntents.swift`의 네 줄 패턴을 그대로 따른다(줄 15·58·167·407 근처). 새 24자리 대문자 16진 ID 두 개를 만든다(`python3 -c "import secrets;print(secrets.token_hex(12).upper())"` 두 번 — 파일 안에 없는 값인지 `grep`으로 확인). `FILEREF`·`BUILDREF`라 부른다.
1. `/* Begin PBXBuildFile section */` 안: `\t\tBUILDREF /* Transcriber.swift in Sources */ = {isa = PBXBuildFile; fileRef = FILEREF /* Transcriber.swift */; };`
2. `/* Begin PBXFileReference section */` 안: `\t\tFILEREF /* Transcriber.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = Transcriber.swift; sourceTree = "<group>"; };`
3. `PlanRoutineIntents.swift */,`가 있는 Runner 그룹 `children` 목록에: `\t\t\t\tFILEREF /* Transcriber.swift */,`
4. Runner 타깃 Sources 단계(`PlanRoutineIntents.swift in Sources */,` 옆)에: `\t\t\t\tBUILDREF /* Transcriber.swift in Sources */,`

- [ ] **Step 6: 가드 통과 + iOS 빌드 확인**

Run: `flutter test test/features/guidance/transcriber_wiring_test.dart test/deploy/ios_deployment_target_test.dart`
Expected: PASS.

Run: `flutter build ios --simulator --debug`
Expected: `✓ Built build/ios/iphonesimulator/Runner.app`. Swift 컴파일 오류가 나면 SDK의 실제 시그니처에 맞춰 고친다(`analyzeSequence(from:)`·`finalizeAndFinish(through:)`·`cancelAndFinishNow()`·`AssetInventory.assetInstallationRequest(supporting:)`는 Mac 실측 스크립트에서 컴파일된 이름이다). **소스 가드는 문법을 보지 않는다 — 이 빌드가 유일한 컴파일 확인이다.**

- [ ] **Step 7: 커밋**

```bash
git add ios/Runner/Transcriber.swift ios/Runner/AppDelegate.swift ios/Runner.xcodeproj/project.pbxproj test/features/guidance/transcriber_wiring_test.dart
git commit -m "feat(ios): SpeechAnalyzer 기기 안 전사 채널(iOS 26+)"
```

---

### Task 5: 재생기에 위치 지정 재생 추가

**Files:**
- Modify: `lib/features/guidance/presentation/widgets/audio_playback.dart`
- Modify: `test/features/guidance/presentation/attachment_tile_test.dart` (`FakePlayback`에 메서드 추가 — 테스트 수는 그대로)

**Interfaces:**
- Produces: `AudioPlayback.playFrom(String path, Duration at)` — 파일이 아직 안 실렸으면 `at` 위치로 싣고, 실렸으면 `seek(at)`, 그다음 재생.

- [ ] **Step 1: 인터페이스와 구현 추가**

`AudioPlayback`에:
```dart
  /// [at] 위치부터 재생한다(글로 보기의 시각 칩).
  Future<void> playFrom(String path, Duration at);
```
`JustAudioPlayback`에:
```dart
  @override
  Future<void> playFrom(String path, Duration at) async {
    if (_loaded != path) {
      await _player.setFilePath(path, initialPosition: at);
      _loaded = path;
    } else {
      await _player.seek(at);
    }
    unawaited(_player.play().catchError((Object _) => _player.pause()));
  }
```

- [ ] **Step 2: 기존 가짜 구현 맞추기**

`attachment_tile_test.dart`의 `FakePlayback`에(기존 필드 이름에 맞춰 기록만):
```dart
  final playFromCalls = <(String, Duration)>[];
  @override
  Future<void> playFrom(String path, Duration at) async => playFromCalls.add((path, at));
```

- [ ] **Step 3: 확인**

Run: `flutter analyze && flutter test test/features/guidance/presentation/attachment_tile_test.dart`
Expected: 깨끗 / PASS(기존 건수 그대로).

- [ ] **Step 4: 커밋**

```bash
git add lib/features/guidance/presentation/widgets/audio_playback.dart test/features/guidance/presentation/attachment_tile_test.dart
git commit -m "feat(guidance): 녹음을 지정 위치부터 재생"
```

---

### Task 6: 글로 보기 화면 (B안) + 라우트

**Files:**
- Create: `lib/features/guidance/presentation/screens/guidance_transcript_screen.dart`
- Modify: `lib/core/router/app_router.dart` (`AppRoutes`에 경로 함수, `record/:id` 하위 라우트)
- Test: `test/features/guidance/presentation/guidance_transcript_screen_test.dart`

**Interfaces:**
- Consumes: `TranscriptionService`·`TranscriptEvent`·`TranscriptionException`·`TranscriptFailure`(Task 3) · `cleanSegments`·`buildTranscriptView`·`activeSegmentIndex`·`formatTranscriptTime`·`formatTranscriptForCopy`(Task 2) · `AudioPlayback.playFrom`(Task 5) · `guidanceFileStoreProvider`·`guidanceAttachmentsProvider`·`audioPlaybackFactoryProvider`.
- Produces:
  - `class GuidanceTranscriptScreen extends ConsumerStatefulWidget { const GuidanceTranscriptScreen({required int recordId, required int attachmentId}); }`
  - 키: `copyAllKey`, `retryKey`, `progressKey`, `preparingKey`, `static Key chipKey(int index)`, `static Key copyKey(int index)`, `static Key gapKey(int startMs)` (index = `cleanSegments` 순서)
  - `AppRoutes.guidanceTranscript(int recordId, int attachmentId) => '/guidance/record/$recordId/transcript/$attachmentId'`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/transcription_service.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/transcript.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_transcript_screen.dart';
import 'package:planroutine/features/guidance/presentation/widgets/audio_playback.dart';

class FakeService implements TranscriptionService {
  // 구독마다 새 컨트롤러 — `다시 시도`가 같은 스트림을 두 번 구독하면 StateError다.
  late StreamController<TranscriptEvent> controller;
  var listened = 0;
  var cancelled = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<TranscriptEvent> transcribe(String path) {
    listened++;
    controller = StreamController<TranscriptEvent>(onCancel: () => cancelled = true);
    return controller.stream;
  }

  void seg(int s, int e, String t) =>
      controller.add(TranscriptSegmentArrived(TranscriptSegment(startMs: s, endMs: e, text: t)));
}

class FakePlayback implements AudioPlayback {
  final playFromCalls = <Duration>[];
  final _pos = StreamController<Duration>.broadcast();
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> playFrom(String path, Duration at) async => playFromCalls.add(at);
  @override
  Future<void> pause() async {}
  @override
  Stream<Duration> get position => _pos.stream;
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

GuidanceAttachment audio({int? durationMs = 70000}) => GuidanceAttachment(
  id: 7,
  recordId: 1,
  type: AttachmentType.audio,
  source: AttachmentSource.recorded,
  fileName: 'a.aac',
  sha256: 'a' * 64,
  byteSize: 10,
  durationMs: durationMs,
  attachedAt: '2026-10-04T15:30:00',
);

void main() {
  late FakeService service;
  late FakePlayback playback;
  late List<String?> clipboard;
  late Directory base;

  // 첨부 줄 테스트와 같은 방법 — 실제 파일 저장소에 임시 폴더를 준다(`guidance/a.aac`).
  setUp(() async {
    base = await Directory.systemTemp.createTemp('transcript_test');
    await Directory('${base.path}/guidance').create();
    await File('${base.path}/guidance/a.aac').writeAsBytes([0]);
    service = FakeService();
    playback = FakePlayback();
    clipboard = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String?);
      }
      return null;
    });
  });
  tearDown(() async => base.delete(recursive: true));

  Future<void> pump(WidgetTester tester, {bool exists = true, int? durationMs = 70000}) async {
    if (!exists) await tester.runAsync(() => File('${base.path}/guidance/a.aac').delete());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transcriptionServiceProvider.overrideWithValue(service),
          audioPlaybackFactoryProvider.overrideWithValue(() => playback),
          guidanceFileStoreProvider.overrideWithValue(GuidanceFileStore(baseDir: () async => base)),
          guidanceAttachmentsProvider(1).overrideWith((ref) async => [audio(durationMs: durationMs)]),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const GuidanceTranscriptScreen(recordId: 1, attachmentId: 7),
                )),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    // 파일 존재 확인은 실제 I/O라 fake-async 밖에서 끝나야 한다(첨부 줄 테스트의 waitUntil과 같은 이유).
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
  }

  testWidgets('문단이 오는 대로 쌓이고, 전사 중에는 전체 복사가 꺼진다', (tester) async {
    await pump(tester);
    expect(find.byKey(GuidanceTranscriptScreen.progressKey), findsOneWidget);
    service.seg(0, 5000, '첫 문단');
    await tester.pump();
    expect(find.text('첫 문단'), findsOneWidget);
    final copyAll = tester.widget<TextButton>(find.byKey(GuidanceTranscriptScreen.copyAllKey));
    expect(copyAll.onPressed, isNull);
    service.seg(15000, 20000, '둘째 문단');
    await service.controller.close();
    await tester.pump();
    expect(find.text('둘째 문단'), findsOneWidget);
    expect(find.byKey(GuidanceTranscriptScreen.progressKey), findsNothing);
    expect(find.byKey(GuidanceTranscriptScreen.gapKey(5000)), findsOneWidget);
    expect(find.text(GuidanceStrings.transcriptGap('00:05', 10)), findsOneWidget);
  });

  testWidgets('시각 칩과 글 없음 줄은 그 위치부터 재생한다', (tester) async {
    await pump(tester);
    service.seg(0, 5000, '가');
    service.seg(15000, 20000, '나');
    await service.controller.close();
    await tester.pump();
    await tester.tap(find.byKey(GuidanceTranscriptScreen.chipKey(1)));
    await tester.tap(find.byKey(GuidanceTranscriptScreen.gapKey(5000)));
    await tester.pump();
    expect(playback.playFromCalls, [const Duration(seconds: 15), const Duration(seconds: 5)]);
  });

  testWidgets('복사·전체 복사 — 스낵바에는 글 내용이 없다', (tester) async {
    await pump(tester);
    service.seg(0, 5000, '비밀 발언');
    await service.controller.close();
    await tester.pump();
    await tester.tap(find.byKey(GuidanceTranscriptScreen.copyKey(0)));
    await tester.pump();
    await tester.tap(find.byKey(GuidanceTranscriptScreen.copyAllKey));
    await tester.pump();
    expect(clipboard, ['비밀 발언', '[00:00] 비밀 발언']);
    final snack = find.byType(SnackBar);
    expect(snack, findsWidgets);
    expect(find.descendant(of: snack.first, matching: find.textContaining('비밀')), findsNothing);
    expect(find.text(GuidanceStrings.transcriptCopied), findsWidgets);
  });

  testWidgets('모델 준비 중 안내', (tester) async {
    await pump(tester);
    service.controller.add(const TranscriptPreparing());
    await tester.pump();
    expect(find.byKey(GuidanceTranscriptScreen.preparingKey), findsOneWidget);
    service.seg(0, 1000, '가');
    await tester.pump();
    expect(find.byKey(GuidanceTranscriptScreen.preparingKey), findsNothing);
  });

  testWidgets('문단 0개면 빈 결과 문구', (tester) async {
    await pump(tester);
    await service.controller.close();
    await tester.pump();
    expect(find.text(GuidanceStrings.transcriptEmpty), findsOneWidget);
  });

  testWidgets('모델 실패는 인터넷 안내 + 다시 시도, 받은 문단은 남긴다', (tester) async {
    await pump(tester);
    service.seg(0, 1000, '남는 문단');
    service.controller.addError(const TranscriptionException(TranscriptFailure.modelDownload));
    await tester.pump();
    expect(find.text('남는 문단'), findsOneWidget);
    expect(find.text(GuidanceStrings.transcriptModelFailed), findsOneWidget);
    expect(find.byKey(GuidanceTranscriptScreen.retryKey), findsOneWidget);
  });

  testWidgets('다시 시도는 처음부터 새로 받아 적는다', (tester) async {
    await pump(tester);
    service.controller.addError(const TranscriptionException(TranscriptFailure.other));
    await tester.pump();
    expect(find.text(GuidanceStrings.transcriptFailed), findsOneWidget);
    await tester.tap(find.byKey(GuidanceTranscriptScreen.retryKey));
    await tester.pump();
    expect(service.listened, 2);
  });

  testWidgets('파일이 없으면 전사하지 않고 파일 없음 문구', (tester) async {
    await pump(tester, exists: false);
    expect(find.text(GuidanceStrings.attachmentMissing), findsOneWidget);
    expect(service.listened, 0);
  });

  testWidgets('녹음 길이를 몰라도(가져온 파일) 진행 표시가 깨지지 않는다', (tester) async {
    await pump(tester, durationMs: null);
    service.seg(0, 5000, '가');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(GuidanceTranscriptScreen.progressKey), findsOneWidget);
  });

  testWidgets('전사 중 뒤로 가면 구독을 끊고 예외가 없다', (tester) async {
    await pump(tester);
    service.seg(0, 1000, '가');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(service.cancelled, isTrue);
    service.controller.add(TranscriptSegmentArrived(
      const TranscriptSegment(startMs: 2000, endMs: 3000, text: '늦게 온 것'),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/guidance/presentation/guidance_transcript_screen_test.dart`
Expected: FAIL — 화면 파일 없음.

- [ ] **Step 3: 화면 구현**

`lib/features/guidance/presentation/screens/guidance_transcript_screen.dart`:
```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/button_semantics.dart';
import '../../data/transcription_service.dart';
import '../../domain/guidance_models.dart';
import '../../domain/transcript.dart';
import '../providers/guidance_providers.dart';
import '../widgets/audio_playback.dart';

/// 녹음 한 개를 기기 안에서 받아 적어 보여 준다(참고용). **저장하지 않는다** — 화면을 닫으면 사라진다.
/// 재생기는 이 화면에 하나뿐이고, 시각 칩·글 없음 줄이 그 위치로 옮겨 재생한다.
class GuidanceTranscriptScreen extends ConsumerStatefulWidget {
  const GuidanceTranscriptScreen({super.key, required this.recordId, required this.attachmentId});

  final int recordId;
  final int attachmentId;

  static const copyAllKey = Key('transcript_copy_all');
  static const retryKey = Key('transcript_retry');
  static const progressKey = Key('transcript_progress');
  static const preparingKey = Key('transcript_preparing');
  static const playKey = Key('transcript_play');
  static Key chipKey(int index) => Key('transcript_chip_$index');
  static Key copyKey(int index) => Key('transcript_copy_$index');
  static Key gapKey(int startMs) => Key('transcript_gap_$startMs');

  @override
  ConsumerState<GuidanceTranscriptScreen> createState() => _GuidanceTranscriptScreenState();
}

class _GuidanceTranscriptScreenState extends ConsumerState<GuidanceTranscriptScreen>
    with WidgetsBindingObserver {
  final _segments = <TranscriptSegment>[];
  StreamSubscription<TranscriptEvent>? _sub;
  AudioPlayback? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playingSub;
  File? _file;
  int? _durationMs;
  var _missing = false;
  var _preparing = false;
  var _done = false;
  TranscriptFailure? _failure;
  var _positionMs = 0;
  var _playing = false;

  /// 첨부 목록은 autoDispose라 `.future`를 읽는 동안 리스너가 없으면 버려진다 — 화면 수명 동안 붙잡는다.
  late final ProviderSubscription<AsyncValue<List<GuidanceAttachment>>> _keepAttachments;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keepAttachments = ref.listenManual(guidanceAttachmentsProvider(widget.recordId), (_, _) {});
    _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 첨부 줄과 같은 규칙 — 떠나거나 잠기면 소리를 멈춘다. 전사는 그대로 둔다.
    if (state != AppLifecycleState.resumed && _playing) {
      unawaited(_player?.pause().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAttachments.close();
    _sub?.cancel();
    _posSub?.cancel();
    _playingSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final attachments = await ref.read(guidanceAttachmentsProvider(widget.recordId).future);
    GuidanceAttachment? a;
    for (final x in attachments) {
      if (x.id == widget.attachmentId) a = x;
    }
    final file = a == null ? null : await ref.read(guidanceFileStoreProvider).fileOf(a.fileName);
    final exists = file != null && await file.exists();
    if (!mounted) return;
    setState(() {
      _file = file;
      _durationMs = a?.durationMs;
      _missing = !exists;
    });
    if (exists) _listen(file.path);
  }

  void _listen(String path) {
    _sub?.cancel();
    setState(() {
      _segments.clear();
      _done = false;
      _failure = null;
      _preparing = false;
    });
    _sub = ref.read(transcriptionServiceProvider).transcribe(path).listen(
      (e) {
        if (!mounted) return;
        setState(() {
          switch (e) {
            case TranscriptPreparing():
              _preparing = true;
            case TranscriptSegmentArrived(:final segment):
              _preparing = false;
              _segments.add(segment);
          }
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _preparing = false;
          _done = true;
          _failure = e is TranscriptionException ? e.failure : TranscriptFailure.other;
        });
      },
      onDone: () {
        if (mounted) setState(() => _done = true);
      },
    );
  }

  AudioPlayback _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = ref.read(audioPlaybackFactoryProvider)();
    _posSub = p.position.listen((d) {
      if (mounted) setState(() => _positionMs = d.inMilliseconds);
    });
    _playingSub = p.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    });
    return _player = p;
  }

  Future<void> _playFrom(int ms) async {
    final file = _file;
    if (file == null || _missing) return;
    setState(() => _positionMs = ms);
    await _ensurePlayer().playFrom(file.path, Duration(milliseconds: ms));
  }

  Future<void> _togglePlay() async {
    final file = _file;
    if (file == null || _missing) return;
    final p = _ensurePlayer();
    if (_playing) {
      await p.pause();
    } else {
      await p.playFrom(file.path, Duration(milliseconds: _positionMs));
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    // 상수 문구만 — 스낵바는 잠금 덮개 밖에 남는다.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text(GuidanceStrings.transcriptCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = cleanSegments(_segments);
    final items = buildTranscriptView(_segments);
    final active = activeSegmentIndex(visible, _positionMs);
    final canCopyAll = _done && visible.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(GuidanceStrings.transcriptTitle),
            const SizedBox(width: AppSizes.spacing8),
            _Tag(),
          ],
        ),
        actions: [
          TextButton(
            key: GuidanceTranscriptScreen.copyAllKey,
            onPressed: canCopyAll ? () => _copy(formatTranscriptForCopy(_segments)) : null,
            child: const Text(GuidanceStrings.transcriptCopyAll),
          ),
        ],
      ),
      body: _missing
          ? Center(child: Text(GuidanceStrings.attachmentMissing, style: AppTextStyles.bodyM))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spacing16, AppSizes.spacing8, AppSizes.spacing16, AppSizes.spacing20),
              children: [
                _playerCard(),
                if (!_done) _progress(visible),
                if (_preparing) _preparingBox(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
                  child: Text(GuidanceStrings.transcriptNotice,
                      style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
                ),
                for (final item in items)
                  switch (item) {
                    TranscriptParagraph(:final segment) =>
                      _paragraph(visible.indexOf(segment), segment, visible.indexOf(segment) == active),
                    TranscriptGap(:final startMs, :final lengthMs) => _gap(startMs, lengthMs),
                  },
                if (_done && _failure == null && visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.spacing20),
                    child: Text(GuidanceStrings.transcriptEmpty,
                        textAlign: TextAlign.center, style: AppTextStyles.bodyM),
                  ),
                if (_failure case final failure?) _failureBox(failure),
              ],
            ),
    );
  }

  Widget _playerCard() {
    final total = _durationMs;
    final ratio = total == null || total <= 0 ? null : (_positionMs / total).clamp(0.0, 1.0);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        side: BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        child: Row(
          children: [
            IconButton.filled(
              key: GuidanceTranscriptScreen.playKey,
              style: IconButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white),
              onPressed: _togglePlay,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow,
                  semanticLabel: _playing ? GuidanceStrings.pause : GuidanceStrings.play),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ratio != null)
                    LinearProgressIndicator(value: ratio, color: AppColors.gold, backgroundColor: AppColors.line),
                  const SizedBox(height: AppSizes.spacing4),
                  Text(
                    total == null
                        ? formatTranscriptTime(_positionMs)
                        : '${formatTranscriptTime(_positionMs)} / ${formatTranscriptTime(total)}',
                    style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress(List<TranscriptSegment> visible) {
    final total = _durationMs;
    final reached = visible.isEmpty ? 0 : visible.last.endMs;
    final ratio = total == null || total <= 0 ? null : (reached / total).clamp(0.0, 1.0);
    return Padding(
      key: GuidanceTranscriptScreen.progressKey,
      padding: const EdgeInsets.only(top: AppSizes.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            total == null
                ? GuidanceStrings.transcriptProgress
                : '${GuidanceStrings.transcriptProgress}  ${formatTranscriptTime(reached)} / ${formatTranscriptTime(total)}',
            style: AppTextStyles.bodyS.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSizes.spacing4),
          // 길이를 모르면 값 없는 막대(왕복 애니메이션) — 0으로 나누지 않는다.
          LinearProgressIndicator(value: ratio, color: AppColors.gold, backgroundColor: AppColors.line),
          const SizedBox(height: AppSizes.spacing4),
          Text(GuidanceStrings.transcriptProgressNotice,
              style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
        ],
      ),
    );
  }

  Widget _preparingBox() => Container(
    key: GuidanceTranscriptScreen.preparingKey,
    margin: const EdgeInsets.only(top: AppSizes.spacing8),
    padding: const EdgeInsets.all(AppSizes.spacing12),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppSizes.radius12),
    ),
    child: Text(GuidanceStrings.transcriptPreparing, style: AppTextStyles.bodyS),
  );

  Widget _paragraph(int index, TranscriptSegment s, bool active) {
    final time = formatTranscriptTime(s.startMs);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          side: BorderSide(color: active ? AppColors.goldFill : AppColors.line, width: active ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ButtonSemantics(
                    label: GuidanceStrings.transcriptPlayFrom(time),
                    onTap: () => _playFrom(s.startMs),
                    child: InkWell(
                      key: GuidanceTranscriptScreen.chipKey(index),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      onTap: () => _playFrom(s.startMs),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 32),
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing12),
                        decoration: BoxDecoration(
                          color: active ? AppColors.goldFill : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 색만으로 두지 않는다 — 재생 중이면 모양도 바뀐다.
                            Icon(active && _playing ? Icons.pause : Icons.play_arrow,
                                size: 14, color: active ? AppColors.onGold : AppColors.ink),
                            const SizedBox(width: AppSizes.spacing4),
                            Text(time,
                                style: AppTextStyles.bodyS.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: active ? AppColors.onGold : AppColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: GuidanceTranscriptScreen.copyKey(index),
                    onPressed: () => _copy(s.text.trim()),
                    child: const Text(GuidanceStrings.transcriptCopy),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacing4),
              SelectableText(s.text.trim(), style: AppTextStyles.bodyM.copyWith(height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gap(int startMs, int lengthMs) {
    final label = GuidanceStrings.transcriptGap(formatTranscriptTime(startMs), lengthMs ~/ 1000);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
      child: OutlinedButton.icon(
        key: GuidanceTranscriptScreen.gapKey(startMs),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(40),
          foregroundColor: AppColors.sub,
          side: BorderSide(color: AppColors.line),
        ),
        onPressed: () => _playFrom(startMs),
        icon: const Icon(Icons.play_arrow, size: 14),
        label: Text(label, style: AppTextStyles.bodyS),
      ),
    );
  }

  Widget _failureBox(TranscriptFailure failure) {
    final (text, canRetry) = switch (failure) {
      TranscriptFailure.modelDownload => (GuidanceStrings.transcriptModelFailed, true),
      TranscriptFailure.fileNotFound => (GuidanceStrings.attachmentMissing, false),
      TranscriptFailure.unsupported || TranscriptFailure.other => (GuidanceStrings.transcriptFailed, true),
    };
    final file = _file;
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacing12),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center,
              style: AppTextStyles.bodyM.copyWith(color: AppColors.error)),
          if (canRetry && file != null)
            TextButton(
              key: GuidanceTranscriptScreen.retryKey,
              onPressed: () => _listen(file.path),
              child: const Text(GuidanceStrings.transcriptRetry),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.sub),
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
    ),
    child: Text(GuidanceStrings.transcribeTag,
        style: AppTextStyles.bodyS.copyWith(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w600)),
  );
}
```
> 토큰 이름(`AppSizes.radius14`·`radius12`·`radiusFull`·`spacing4`, `AppColors.error`, `AppTextStyles.bodyS/bodyM`)은 내보내기 시트·첨부 줄이 이미 쓰는 것이다. analyze가 없는 이름을 잡으면 그 파일들에서 쓰는 이름으로 맞춘다.

- [ ] **Step 4: 라우트 추가**

`AppRoutes`에(`guidanceHistory` 아래):
```dart
  static String guidanceTranscript(int id, int attachmentId) =>
      '/guidance/record/$id/transcript/$attachmentId';
```
`app_router.dart`의 `record/:id` 하위 `routes:`에 `history` 라우트 다음으로:
```dart
                    GoRoute(
                      path: 'transcript/:attachmentId',
                      builder: (context, state) => GuidanceTranscriptScreen(
                        recordId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                        attachmentId:
                            int.tryParse(state.pathParameters['attachmentId'] ?? '') ?? -1,
                      ),
                    ),
```
(import `../../features/guidance/presentation/screens/guidance_transcript_screen.dart`)

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/features/guidance/presentation/guidance_transcript_screen_test.dart && flutter analyze`
Expected: PASS(10건), analyze 깨끗. 기존 가드도 확인: `flutter test test/features/guidance/ test/shared/ test/core/`
(`button_semantics_guard_test`·`no_tooltip_guard_test`·`guidance_root_navigator_guard_test`·`guidance_isolation_test`가 새 화면을 훑는다 — 걸리면 가드가 아니라 화면을 고친다.)

- [ ] **Step 6: 커밋**

```bash
git add lib/features/guidance/presentation/screens/guidance_transcript_screen.dart lib/core/router/app_router.dart test/features/guidance/presentation/guidance_transcript_screen_test.dart
git commit -m "feat(guidance): 글로 보기 화면 — 문단 카드·시각 재생·글 없음 구간·복사"
```

---

### Task 7: 기록 보기에 `글로 보기` 버튼

**Files:**
- Modify: `lib/features/guidance/presentation/widgets/attachment_tile.dart`
- Modify: `lib/features/guidance/presentation/screens/guidance_detail_screen.dart`
- Test: `test/features/guidance/presentation/attachment_tile_test.dart`(추가), `test/features/guidance/presentation/guidance_detail_screen_test.dart`(추가)

**Interfaces:**
- Consumes: `transcriptAvailableProvider`(Task 3), `AppRoutes.guidanceTranscript`(Task 6)
- Produces: `AttachmentTile({..., VoidCallback? onTranscribe})`, `static Key transcribeKey(int id)`

- [ ] **Step 1: 실패하는 테스트 작성**

`attachment_tile_test.dart`의 `host`·`pump`에 `VoidCallback? onTranscribe`를 더해 `AttachmentTile(..., onTranscribe: onTranscribe)`로 넘긴다(기존 호출은 그대로). 테스트 추가(이 파일의 `audio` 픽스처는 `r.m4a`, setUp이 그 파일을 만든다):
```dart
  testWidgets('onTranscribe가 있고 파일이 있으면 글로 보기 버튼', (tester) async {
    var tapped = 0;
    await pump(tester, audio, onTranscribe: () => tapped++);
    await tester.tap(find.byKey(AttachmentTile.transcribeKey(1)));
    expect(tapped, 1);
    expect(find.text(GuidanceStrings.transcribeTag), findsOneWidget);
  });

  testWidgets('onTranscribe가 없으면(편집 화면·미지원 기기) 버튼이 없다', (tester) async {
    await pump(tester, audio);
    expect(find.byKey(AttachmentTile.transcribeKey(1)), findsNothing);
  });

  testWidgets('파일이 없으면 글로 보기를 숨긴다', (tester) async {
    await tester.pumpWidget(host(audio.copyWith(id: 9, fileName: 'none.m4a'), onTranscribe: () {}));
    await waitUntil(tester, () => find.textContaining(GuidanceStrings.attachmentMissing).evaluate().isNotEmpty);
    expect(find.byKey(AttachmentTile.transcribeKey(9)), findsNothing);
  });
```
`guidance_detail_screen_test.dart`에 추가 — 녹음 첨부가 있는 기록을 만들고(그 파일의 기존 첨부 테스트가 쓰는 방법 그대로), `transcriptAvailableProvider`를 덮어써 두 경우를 본다:
```dart
  testWidgets('지원하지 않는 기기에서는 글로 보기가 없다', (tester) async {
    // pump의 overrides에 transcriptAvailableProvider.overrideWith((ref) async => false) 추가
    ...
    expect(find.text(GuidanceStrings.transcribe), findsNothing);
  });
  testWidgets('지원 기기에서는 녹음 줄에 글로 보기가 있고 사진 줄에는 없다', (tester) async {
    // transcriptAvailableProvider.overrideWith((ref) async => true), 녹음 1 + 사진 1
    ...
    expect(find.text(GuidanceStrings.transcribe), findsOneWidget);
  });
```
(두 테스트 모두 `pump`에 `overrides` 매개변수를 더해 넘긴다. 파일 존재는 `guidanceFileStoreProvider.overrideWithValue(GuidanceFileStore(baseDir: () async => base))`로 덮고, setUp에서 `base/guidance/`에 녹음 첨부의 `fileName`과 같은 파일을 만든다 — 파일이 없으면 버튼이 숨으므로 첫 테스트가 헛통과하지 않게 한다.)

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/guidance/presentation/attachment_tile_test.dart test/features/guidance/presentation/guidance_detail_screen_test.dart`
Expected: FAIL — `onTranscribe`·`transcribeKey` 없음.

- [ ] **Step 3: 구현**

`AttachmentTile`에 필드·키 추가:
```dart
  /// 녹음을 글로 보기(참고용 전사). 지원 기기의 기록 보기에서만 넘긴다.
  final VoidCallback? onTranscribe;
  static Key transcribeKey(int id) => Key('att_transcribe_$id');
```
`build`의 `Padding(child: Row(...))`를 `Column`으로 감싸 아래에 버튼을 붙인다:
```dart
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [/* 기존 그대로 */]),
            if (widget.onTranscribe != null && file != null && !_missing) ...[
              const SizedBox(height: AppSizes.spacing6),
              TextButton.icon(
                key: AttachmentTile.transcribeKey(id),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: AppColors.surfaceVariant,
                  foregroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius8)),
                ),
                onPressed: widget.onTranscribe,
                icon: const Icon(Icons.notes, size: 18),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(GuidanceStrings.transcribe),
                    const SizedBox(width: AppSizes.spacing6),
                    Text(GuidanceStrings.transcribeTag,
                        style: AppTextStyles.bodyS.copyWith(fontSize: 12, color: AppColors.sub)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
```
(`AppSizes.spacing6`이 없으면 `spacing4`.)

`guidance_detail_screen.dart`의 `build`에서:
```dart
    final canTranscribe = ref.watch(transcriptAvailableProvider).valueOrNull ?? false;
```
첨부 루프의 `AttachmentTile(...)`에:
```dart
                      child: AttachmentTile(
                        key: ValueKey(a.id),
                        attachment: a,
                        now: now,
                        onTranscribe: canTranscribe && a.type == AttachmentType.audio && a.id != null
                            ? () => context.push(AppRoutes.guidanceTranscript(recordId, a.id ?? -1))
                            : null,
                      ),
```
(`go_router`의 `context.push` — 이 화면이 이미 import하고 있지 않으면 `package:go_router/go_router.dart`와 `AppRoutes` import 추가. 지도 기록의 다른 하위 화면 이동과 같은 방식인지 `edit`·`history` 이동 코드를 보고 맞춘다.)

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/guidance/ && flutter analyze`
Expected: PASS, 깨끗.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/guidance/presentation/widgets/attachment_tile.dart lib/features/guidance/presentation/screens/guidance_detail_screen.dart test/features/guidance/presentation/attachment_tile_test.dart test/features/guidance/presentation/guidance_detail_screen_test.dart
git commit -m "feat(guidance): 기록 보기 녹음 줄에 글로 보기 버튼"
```

---

### Task 8: 내보내기 `녹음만`

**Files:**
- Modify: `lib/features/guidance/domain/guidance_export.dart`
- Modify: `lib/features/guidance/data/guidance_exporter.dart`
- Modify: `lib/features/guidance/presentation/widgets/guidance_export_sheet.dart`
- Modify: `lib/core/constants/strings/guidance_strings.dart`
- Test: `test/features/guidance/domain/guidance_export_test.dart` · `test/features/guidance/data/guidance_exporter_test.dart` · `test/features/guidance/presentation/guidance_export_sheet_test.dart` (모두 추가)

**Interfaces:**
- Produces:
  - `enum ExportKind { bundle, audioOnly, pdfOnly }`
  - `class AudioExportFile { const AudioExportFile({required this.attachment, required this.outName}); final GuidanceAttachment attachment; final String outName; }`
  - `List<AudioExportFile> buildAudioOnlyFiles({required String createdAt, required List<GuidanceAttachment> attachments, required Set<int> selectedIds})`
  - `GuidanceExporter.copyAudioForShare({required GuidanceRecord record, required List<GuidanceAttachment> attachments, required Set<int> selectedIds, required Directory dir}) → Future<List<File>>` — 실패하면 만든 사본을 지우고 다시 던진다.
  - 시트: `typedef ShareFiles = Future<bool> Function(List<String> paths, Rect? origin);` · `GuidanceExportSheet({..., ShareFiles? shareFiles, Future<Directory> Function()? tempDir})` · `static const audioOnlyKey = Key('guidance_export_audio_only');` · `static const saveOneOnlyKey = Key('guidance_export_save_one_only');`
  - 문구: `exportAudioOnly = '녹음만'`, `exportAudioOnlySubtitle = '원본 파일 그대로 · 받는 쪽에서 바로 들을 수 있어요'`, `exportAudioOnlyExcluded = '녹음만 보낼 때는 빠져요'`, `exportAudioSaveOneOnly = '여러 개는 공유로 보내 주세요'`

- [ ] **Step 1: 도메인 테스트 작성**

`guidance_export_test.dart`에 추가(기존 첨부 픽스처 도우미 사용):
```dart
  group('buildAudioOnlyFiles', () {
    test('고른 녹음만, 고른 것 사이 순번으로, 지도기록_ 접두 + 원래 확장자', () {
      final files = buildAudioOnlyFiles(
        createdAt: '2026-10-04T15:30:00',
        attachments: [
          att(1, 'p.heic', '2026-10-04T15:31:00', type: AttachmentType.image),
          att(2, 'r.aac', '2026-10-04T15:32:00'),
          att(3, 'r2.M4A', '2026-10-04T15:33:00'),
        ],
        selectedIds: {1, 2, 3},
      );
      expect(files.map((f) => f.outName), ['지도기록_20261004-1530_01.aac', '지도기록_20261004-1530_02.m4a']);
    });
    test('뺀 첨부·고르지 않은 녹음은 빠진다', () {
      final files = buildAudioOnlyFiles(
        createdAt: '2026-10-04T15:30:00',
        attachments: [
          att(2, 'a.aac', '2026-10-04T15:32:00', removedAt: '2026-10-05T00:00:00'),
          att(3, 'b.aac', '2026-10-04T15:33:00'),
          att(4, 'c.aac', '2026-10-04T15:34:00'),
        ],
        selectedIds: {2, 4},
      );
      expect(files.map((f) => f.attachment.id), [4]);
    });
  });
```
(이 파일의 `att(id, fileName, attachedAt, {type = audio, removedAt})` 도우미를 그대로 쓴다.)

- [ ] **Step 2: 실패 확인 → 구현 → 통과**

Run: `flutter test test/features/guidance/domain/guidance_export_test.dart` → FAIL.

`guidance_export.dart`:
```dart
/// 무엇을 내보내나 — PDF와 원본을 한 파일로 / 녹음 원본만 / PDF 한 장.
enum ExportKind { bundle, audioOnly, pdfOnly }

/// 녹음만 보낼 때의 파일 하나. 원본을 그대로 복사해 이 이름을 붙인다(바이트가 같아 SHA-256이 대조된다).
class AudioExportFile {
  const AudioExportFile({required this.attachment, required this.outName});
  final GuidanceAttachment attachment;
  final String outName;
}

List<AudioExportFile> buildAudioOnlyFiles({
  required String createdAt,
  required List<GuidanceAttachment> attachments,
  required Set<int> selectedIds,
}) {
  final plan = buildExportPlan(
    createdAt: createdAt,
    attachments: [for (final a in attachments) if (a.type == AttachmentType.audio) a],
    selectedIds: selectedIds,
  );
  // ZIP 안 이름과 같은 규칙에 바깥 접두만 붙인다 — 제목은 넣지 않는다.
  return [
    for (final e in plan.entries) AudioExportFile(attachment: e.attachment, outName: '지도기록_${e.innerName}'),
  ];
}
```
`guidance_exporter.dart`의 `build` 첫 줄에(호출 경로 실수 방지):
```dart
    assert(kind != ExportKind.audioOnly, '녹음만은 copyAudioForShare를 쓴다');
```
Run 다시 → PASS. `flutter analyze`로 `ExportKind`를 쓰는 다른 곳(`guidance_pdf_builder.dart:219`는 `== ExportKind.bundle` 비교라 영향 없음)을 확인.

- [ ] **Step 3: 복사 테스트 작성**

`guidance_exporter_test.dart`에 추가(기존 파일의 `GuidanceFileStore` 임시 폴더 설정을 그대로 쓴다):
```dart
  test('copyAudioForShare는 원본 바이트 그대로 새 이름으로 복사한다', () async {
    // store에 'r.aac'(바이트 [1,2,3]) 저장해 둔 상태
    final out = await exporter.copyAudioForShare(
      record: record, attachments: [audioAtt], selectedIds: {audioAtt.id!}, dir: tmpOut);
    expect(out.single.path.endsWith('지도기록_20261004-1530_01.aac'), isTrue);
    expect(out.single.readAsBytesSync(), [1, 2, 3]);
  });

  test('복사 실패 시 사본을 남기지 않는다', () async {
    // 녹음 둘 중 둘째 파일은 store에 없다
    await expectLater(
      exporter.copyAudioForShare(
        record: record, attachments: [audioAtt, missingAtt], selectedIds: {audioAtt.id!, missingAtt.id!}, dir: tmpOut),
      throwsA(anything),
    );
    expect(tmpOut.listSync(), isEmpty);
  });
```

- [ ] **Step 4: 복사 구현 → 통과**

`guidance_exporter.dart`에(import `dart:io`, `package:path/path.dart' as p`):
```dart
  /// 녹음만 — 메모리에 읽지 않고 [dir]에 복사한다(한 시간 녹음도 메모리를 쓰지 않는다).
  /// 하나라도 실패하면 이미 만든 사본을 지우고 다시 던진다 — 기록이 담긴 파일을 남기지 않는다.
  Future<List<File>> copyAudioForShare({
    required GuidanceRecord record,
    required List<GuidanceAttachment> attachments,
    required Set<int> selectedIds,
    required Directory dir,
  }) async {
    await dir.create(recursive: true);
    final made = <File>[];
    try {
      for (final f in buildAudioOnlyFiles(
        createdAt: record.createdAt, attachments: attachments, selectedIds: selectedIds)) {
        final src = await fileStore.fileOf(f.attachment.fileName);
        made.add(await src.copy(p.join(dir.path, f.outName)));
      }
      return made;
    } catch (_) {
      for (final f in made) {
        try {
          await f.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }
```
Run: `flutter test test/features/guidance/data/guidance_exporter_test.dart` → PASS.

- [ ] **Step 5: 시트 테스트 작성**

`guidance_export_sheet_test.dart`의 `pump`에 `shareFiles`·`tempDir` 주입을 더하고(기존 테스트 호출은 그대로), 실제 `GuidanceExporter`가 필요한 녹음만 경로는 `FakeExporter`에 `copyAudioForShare` 재정의를 더한다:
```dart
  // FakeExporter에 추가
  final audioCalls = <Set<int>>[];
  var failAudio = false;
  @override
  Future<List<File>> copyAudioForShare({
    required GuidanceRecord record,
    required List<GuidanceAttachment> attachments,
    required Set<int> selectedIds,
    required Directory dir,
  }) async {
    audioCalls.add({...selectedIds});
    if (failAudio) throw StateError('실패');
    await dir.create(recursive: true);
    return [for (final id in selectedIds) File('${dir.path}/a$id.aac')..writeAsBytesSync([id])];
  }
```
테스트:
```dart
  testWidgets('녹음이 없으면 녹음만 선택지가 없다', (tester) async {
    await pump(tester, attachments: [att(1, AttachmentType.image)], available: {1});
    expect(find.byKey(GuidanceExportSheet.audioOnlyKey), findsNothing);
  });

  testWidgets('녹음만을 고르면 사진 줄이 꺼지고 고른 녹음만 공유한다', (tester) async {
    await pump(tester, attachments: [att(1, AttachmentType.audio), att(2, AttachmentType.image)], available: {1, 2});
    await tester.tap(find.byKey(GuidanceExportSheet.audioOnlyKey));
    await tester.pump();
    final photo = tester.widget<CheckboxListTile>(find.byKey(GuidanceExportSheet.attachmentKey(2)));
    expect(photo.onChanged, isNull);
    expect(find.text(GuidanceStrings.exportAudioOnlyExcluded), findsOneWidget);
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(exporter.audioCalls, [{1}]);
    expect(sharedPaths.single, hasLength(1));
  });

  testWidgets('공유가 끝나면 임시 사본을 지운다', (tester) async {
    await pump(tester, attachments: [att(1, AttachmentType.audio)], available: {1});
    await tester.tap(find.byKey(GuidanceExportSheet.audioOnlyKey));
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(File(sharedPaths.single.single).existsSync(), isFalse);
  });

  testWidgets('복사 실패는 시트 안 실패 줄', (tester) async {
    exporter.failAudio = true;
    await pump(tester, attachments: [att(1, AttachmentType.audio)], available: {1});
    await tester.tap(find.byKey(GuidanceExportSheet.audioOnlyKey));
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.exportFailed), findsOneWidget);
  });

  testWidgets('안드로이드 녹음만 2개 이상이면 저장이 꺼지고 안내', (tester) async {
    await pump(tester, attachments: [att(1, AttachmentType.audio), att(2, AttachmentType.audio)],
        available: {1, 2}, isAndroid: true);
    await tester.tap(find.byKey(GuidanceExportSheet.audioOnlyKey));
    await tester.pump();
    expect(tester.widget<OutlinedButton>(find.byKey(GuidanceExportSheet.saveKey)).onPressed, isNull);
    expect(find.byKey(GuidanceExportSheet.saveOneOnlyKey), findsOneWidget);
  });

  testWidgets('안드로이드 녹음만 1개면 저장에 원본 바이트를 넘긴다', (tester) async {
    await pump(tester, attachments: [att(1, AttachmentType.audio), att(2, AttachmentType.audio)],
        available: {1, 2}, isAndroid: true);
    await tester.tap(find.byKey(GuidanceExportSheet.audioOnlyKey));
    await tester.tap(find.byKey(GuidanceExportSheet.attachmentKey(2)));
    await tester.pump();
    await tester.tap(find.byKey(GuidanceExportSheet.saveKey));
    await tester.pumpAndSettle();
    expect(savedOutputs.single.bytes, [1]);
  });
```
(`sharedPaths`는 `List<List<String>>`, `savedOutputs`는 `List<ExportOutput>` — `pump`에서 `shareFiles: (paths, _) async { sharedPaths.add(paths); return true; }`, `save: (out) async { savedOutputs.add(out); return true; }`로 모은다. 기존 `saved` 리스트가 이미 있으면 그 이름을 쓴다. 임시 폴더는 `tempDir: () async => Directory.systemTemp.createTempSync('exp')`. 파일 I/O가 있는 탭은 필요하면 `tester.runAsync`로 감싼다.)

- [ ] **Step 6: 시트 구현 → 통과**

`guidance_export_sheet.dart`:
1. typedef와 기본 구현 추가:
```dart
/// 여러 파일 공유. 보냈으면(또는 결과를 알 수 없으면) true.
typedef ShareFiles = Future<bool> Function(List<String> paths, Rect? origin);

Future<bool> _shareFilesViaSheet(List<String> paths, Rect? origin) async {
  final result = await Share.shareXFiles([for (final p in paths) XFile(p)], sharePositionOrigin: origin);
  return result.status != ShareResultStatus.dismissed;
}
```
2. `showGuidanceExportSheet`·`GuidanceExportSheet`에 `@visibleForTesting ShareFiles? shareFiles`, `@visibleForTesting Future<Directory> Function()? tempDir`를 받아 넘긴다. 키 `audioOnlyKey`·`saveOneOnlyKey` 추가.
3. 상태에 계산 프로퍼티:
```dart
  bool get _audioOnly => _kind == ExportKind.audioOnly;
  bool get _hasAudio => _visible.any((a) => a.type == AttachmentType.audio && widget.availableIds.contains(a.id));
  int get _pickedAudio => _visible.where((a) => a.type == AttachmentType.audio && _selected.contains(a.id)).length;
  bool get _canSend => !_busy && switch (_kind) {
    ExportKind.pdfOnly => true,
    ExportKind.bundle => _selected.isNotEmpty,
    ExportKind.audioOnly => _pickedAudio > 0,
  };
  bool get _canSave => _canSend && (!_audioOnly || _pickedAudio == 1);
```
4. 라디오: `bundle` 다음에
```dart
                  if (_hasAudio)
                    RadioListTile<ExportKind>(
                      key: GuidanceExportSheet.audioOnlyKey,
                      value: ExportKind.audioOnly,
                      title: const Text(GuidanceStrings.exportAudioOnly),
                      subtitle: const Text(GuidanceStrings.exportAudioOnlySubtitle),
                    ),
```
5. `_attachmentRow`: `final excluded = _audioOnly && a.type == AttachmentType.image;` → `value: !excluded && present && _selected.contains(id)`, `onChanged: present && !excluded ? ... : null`, 부제는 `excluded ? GuidanceStrings.exportAudioOnlyExcluded : (기존)`.
6. 공유·저장 분기:
```dart
  Future<void> _share() => _audioOnly
      ? _runAudio()
      : _run((out) async => await (widget.share ?? shareViaSheet)(out, _origin()) ? GuidanceStrings.exportShared : null);

  Future<void> _save() => _audioOnly
      ? _runAudio(save: true)
      : _run((out) async => await (widget.save ?? _saveViaPicker)(out) ? GuidanceStrings.exportSaved : null);

  /// 녹음만 — 원본을 임시 폴더로 복사해 보내고, 결과와 무관하게 사본을 지운다.
  Future<void> _runAudio({bool save = false}) async {
    if (!(save ? _canSave : _canSend)) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    String? done;
    List<File> copies = const [];
    try {
      final base = await (widget.tempDir ?? getTemporaryDirectory)();
      copies = await ref.read(guidanceExporterProvider).copyAudioForShare(
        record: widget.record,
        attachments: _visible,
        selectedIds: _selected,
        dir: Directory(p.join(base.path, 'guidance_export')),
      );
      if (save) {
        // SAF 저장 창은 바이트를 요구한다 — 1개일 때만 열린다.
        final f = copies.single;
        final ok = await (widget.save ?? _saveViaPicker)(
          ExportOutput(fileName: p.basename(f.path), bytes: await f.readAsBytes()));
        done = ok ? GuidanceStrings.exportSaved : null;
      } else {
        final ok = await (widget.shareFiles ?? _shareFilesViaSheet)([for (final f in copies) f.path], _origin());
        done = ok ? GuidanceStrings.exportShared : null;
      }
    } catch (_) {
      if (mounted) setState(() => _status = GuidanceStrings.exportFailed);
    } finally {
      for (final f in copies) {
        try {
          await f.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
    if (done != null && mounted) await Navigator.of(context).maybePop(done);
  }
```
7. 저장 버튼 `onPressed: _canSave ? _save : null`, 그 아래(안드로이드·녹음만·2개 이상일 때):
```dart
            if (_android && _audioOnly && _pickedAudio > 1)
              Padding(
                key: GuidanceExportSheet.saveOneOnlyKey,
                padding: const EdgeInsets.only(top: AppSizes.spacing4),
                child: Text(GuidanceStrings.exportAudioSaveOneOnly,
                    style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
              ),
```
8. 문구 넷을 `GuidanceStrings`에 추가(Interfaces 참고).

Run: `flutter test test/features/guidance/ && flutter analyze`
Expected: PASS, 깨끗. (기존 시트 테스트가 `_canSend` 변경으로 깨지면 동작이 바뀐 것이다 — bundle/pdf의 기존 조건을 그대로 유지했는지 확인한다.)

- [ ] **Step 7: 커밋**

```bash
git add lib/features/guidance/domain/guidance_export.dart lib/features/guidance/data/guidance_exporter.dart lib/features/guidance/presentation/widgets/guidance_export_sheet.dart lib/core/constants/strings/guidance_strings.dart test/features/guidance/
git commit -m "feat(guidance): 내보내기에 녹음만 — 원본 그대로 공유, 안드로이드 저장은 1개만"
```

---

### Task 9: 시뮬레이터 확인 · 문서 · 정리

**Files:**
- Modify: `CLAUDE.md` (핵심 기능 15번, 지도 기록 절, 테스트 수)
- Modify: `docs/superpowers/specs/2026-10-07-guidance-transcript-design.md` (실측 결과)
- Delete: scratchpad의 `stt/`·`design/` 임시 파일

**Interfaces:** 없음.

- [ ] **Step 1: 전체 테스트·분석**

Run: `flutter analyze && flutter test`
Expected: 깨끗 / 전부 PASS. 통과 건수를 적어 둔다(직전 기준 1679).

- [ ] **Step 2: iOS 시뮬레이터 실행 확인** (`driving-ios-simulator` 스킬 절차)

안드로이드 빌드 뒤라면 먼저 `cd android && ./gradlew --stop`(메모리). 시뮬레이터에서 앱 실행 → 설정 › 기능 관리 › 지도 기록 켜기 → 새 기록 → 첨부 `가져오기`로 오디오 파일(scratchpad의 합성 `dialog.aac`를 시뮬레이터 파일 앱에 넣어 두기: `xcrun simctl addmedia`는 사진·동영상용이므로 파일 앱 경로는 `xcrun simctl get_app_container booted com.apple.DocumentsApp groups` 대신 드래그 앤 드롭) → 저장 → 기록 보기.
- Task 1 결과가 "시뮬레이터에서 됨"이면: `글로 보기` → 문단·글 없음 줄·시각 칩 재생·복사 스낵바를 녹화로 확인한다.
- "안 됨"이면: `글로 보기` 버튼이 **보이지 않는 것**만 확인하고, 전사 동작은 **미검증**으로 보고에 적는다(TestFlight 실기기 몫).
- 내보내기 › `녹음만` → 공유시트에 `.aac` 한 파일이 뜨는지, 사진 줄이 꺼지는지 확인한다.

- [ ] **Step 3: Android 에뮬레이터 확인**

`글로 보기`가 없음, 내보내기 `녹음만` → 공유 / `기기에 저장`(1개) → `Download`에 `.aac`가 저장되고 `shasum -a 256`이 첨부 정보의 SHA-256과 같은지 확인.

- [ ] **Step 4: 문서 갱신**

`CLAUDE.md`:
- 핵심 기능 15번 끝에: `녹음은 iOS 26+ 지원 기기에서 **글로 보기**(기기 안 참고용 전사, 저장 안 함)로 훑어볼 수 있고, 내보내기에서 **녹음만** 원본 그대로 보낼 수 있다.`
- `### 지도 기록 (선택 탭)` 절 끝에 `글로 보기` 하위 항목: 설계 경로, 저장 안 함, iOS 26 분기·배포 타깃 16.0 유지, 채널 이름·가드(`transcriber_wiring_test.dart`), 글 없음 8초, 스낵바에 내용 없음, Task 1 시뮬레이터 결과, 녹음만(파일 복사·SHA 일치·안드로이드 저장 1개).
- 기술 스택 표 테스트 칸의 숫자를 Step 1 실측값으로 바꾸고 무엇을 더한 값인지 한 줄.

스펙 `## 검증`에 시뮬레이터·에뮬레이터 실측 결과를 한 줄씩.

- [ ] **Step 5: 임시 파일 정리**

scratchpad의 `stt/`(합성 음성·스크립트·바이너리)와 `design/`(캔버스 원본 사본)을 지운다 — 캔버스는 claude.ai에 남는다. 리포 밖이라 사용자 확인 대상(rm -rf)에 해당하면 먼저 묻는다.

- [ ] **Step 6: 커밋**

```bash
git add CLAUDE.md docs/superpowers/specs/2026-10-07-guidance-transcript-design.md
git commit -m "docs(guidance): 글로 보기·녹음만 공유 반영"
```
