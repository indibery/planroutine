import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/lock/system_sheet_guard.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/recording/guidance_recorder.dart';
import 'package:planroutine/features/guidance/presentation/recording/recording_screen.dart';

class FakeRecorder implements GuidanceRecorder {
  FakeRecorder({this.permitted = true, this.failStart = false, this.failStop = false});
  final bool permitted;
  final bool failStart;
  final bool failStop;
  String? startedAt;
  var stopped = 0;
  @override
  Future<bool> ensurePermission() async => permitted;
  @override
  Future<void> start(String path) async {
    if (failStart) throw StateError('마이크 사용 중');
    startedAt = path;
    File(path).writeAsStringSync('rec');
  }

  @override
  Future<String?> stop() async {
    stopped++;
    if (failStop) throw StateError('멈추기 실패');
    return startedAt;
  }

  @override
  Future<void> dispose() async {}
}

/// 직접 붙이기(화면이 결과를 돌려주지 못하고 사라질 때)를 세는 가짜.
class FakeActions extends GuidanceActions {
  FakeActions(super.ref);
  final attached = <(int, String)>[];
  @override
  Future<GuidanceAttachment> attachRecording({
    required int recordId,
    required String path,
    required int durationMs,
    required DateTime startedAt,
  }) async {
    attached.add((recordId, path));
    return GuidanceAttachment(
      recordId: recordId,
      type: AttachmentType.audio,
      source: AttachmentSource.recorded,
      fileName: path,
      sha256: '',
      byteSize: 0,
      attachedAt: '',
    );
  }
}

void main() {
  late Directory base;
  late FakeActions actions;
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

  /// 고정 횟수 대신 조건이 될 때까지(상한 40회·25ms) 실제 I/O와 프레임을 번갈아 돌린다.
  Future<void> waitUntil(WidgetTester tester, bool Function() cond) async {
    for (var i = 0; i < 40 && !cond(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(cond(), isTrue, reason: '조건이 상한 안에 충족되지 않음');
  }

  /// 아무 일도 일어나지 않아야 하는 경우의 짧은 대기.
  Future<void> idle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
  }

  /// [show]를 false로 바꾸면 MaterialApp 아래가 통째로 사라진다(탭 이동으로 셸이 dispose되는 것).
  Future<void> pump(
    WidgetTester tester, {
    bool permitted = true,
    FakeRecorder? recorder,
    String? readyText,
    ValueNotifier<bool>? show,
  }) async {
    rec = recorder ?? FakeRecorder(permitted: permitted);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRecorderFactoryProvider.overrideWithValue(() => rec),
          guidanceFileStoreProvider.overrideWithValue(GuidanceFileStore(baseDir: () async => base)),
          guidanceActionsProvider.overrideWith((ref) => actions = FakeActions(ref)),
        ],
        child: ValueListenableBuilder<bool>(
          valueListenable: show ?? ValueNotifier(true),
          builder: (_, on, _) => !on
              ? const SizedBox.shrink()
              : MaterialApp(
                  home: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        result = await Navigator.of(context).push<RecordingResult>(
                          MaterialPageRoute(builder: (_) => const RecordingScreen(recordId: 7, title: '복도 다툼')),
                        );
                        popped = true;
                      },
                      child: const Text('열기'),
                    ),
                  ),
                ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await waitUntil(
      tester,
      () => find
          .text(readyText ?? (permitted ? GuidanceStrings.recordingLive : GuidanceStrings.micDenied))
          .evaluate()
          .isNotEmpty,
    );
  }

  testWidgets('허락하면 첨부 폴더 안에 녹음하고, 멈추면 결과를 돌려준다', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.recordingLive), findsOneWidget);
    expect(find.text(GuidanceStrings.recordingLegal), findsOneWidget);
    // 사전 고지 문구는 뺐다(사용자 결정 2026-10-04) — 대화 당사자 녹음은 불법이 아니고, 상대를 불쾌하게 할 수 있다.
    expect(find.textContaining('먼저 알려'), findsNothing);
    expect(rec.startedAt?.contains(GuidanceFileStore.folder), isTrue);
    await tester.tap(find.byKey(RecordingScreen.stopKey));
    await waitUntil(tester, () => popped);
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
    await waitUntil(tester, () => popped);
    expect(rec.stopped, 1);
    expect(popped, isTrue);
    expect(result?.path, rec.startedAt);
  });

  testWidgets('시스템 창 동안의 비활성에는 멈추지 않는다', (tester) async {
    await pump(tester);
    final sheet = Completer<void>();
    final running = SystemSheetGuard.run(() => sheet.future);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await idle(tester);
    expect(rec.stopped, 0);
    expect(popped, isFalse);
    sheet.complete();
    await running;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('뒤로 가기도 녹음을 버리지 않고 결과를 돌려준다', (tester) async {
    await pump(tester);
    await tester.binding.handlePopRoute();
    await waitUntil(tester, () => popped);
    expect(rec.stopped, 1);
    expect(result?.path, rec.startedAt);
  });

  testWidgets('시작이 실패하면 안내를 보이고, 결과 없이 닫을 수 있다', (tester) async {
    await pump(tester, recorder: FakeRecorder(failStart: true), readyText: GuidanceStrings.recordingStartFailed);
    expect(find.text(GuidanceStrings.recordingLive), findsNothing);
    await tester.tap(find.byKey(RecordingScreen.closeKey));
    await waitUntil(tester, () => popped);
    expect(result, isNull);
  });

  testWidgets('멈추는 호출이 실패해도 녹음 경로를 결과로 돌려준다', (tester) async {
    await pump(tester, recorder: FakeRecorder(failStop: true));
    await tester.tap(find.byKey(RecordingScreen.stopKey));
    await waitUntil(tester, () => popped);
    expect(rec.stopped, 1);
    expect(result?.path, rec.startedAt);
  });

  testWidgets('권한 거부 화면에서 앱이 비활성이 되어도 화면이 남는다', (tester) async {
    await pump(tester, permitted: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await idle(tester);
    expect(popped, isFalse);
    expect(find.text(GuidanceStrings.micDenied), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('녹음 화면은 테마와 무관하게 시스템 바 아이콘을 밝게 둔다', (tester) async {
    // 다른 테스트가 먼저 값을 바꿔 뒀어도 통과하지 않도록 반대 값으로 오염시켜 둔다.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    await pump(tester);
    // 라우트 전환이 끝나야 화면이 제자리에서 영역을 덮는다.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final style = SystemChrome.latestStyle;
    expect(style?.systemNavigationBarIconBrightness, Brightness.light);
    expect(style?.statusBarIconBrightness, Brightness.light);
    expect(style?.systemNavigationBarContrastEnforced, isFalse);
  });

  testWidgets('녹음 중 화면이 결과를 돌려주지 못하고 사라지면 멈추고 그 기록에 직접 붙인다', (tester) async {
    final show = ValueNotifier(true);
    await pump(tester, show: show);
    show.value = false;
    await tester.pump();
    await waitUntil(tester, () => actions.attached.isNotEmpty);
    expect(rec.stopped, 1);
    expect(actions.attached.single, (7, rec.startedAt));
  });

  testWidgets('멈춰서 결과를 돌려준 뒤 사라질 때는 직접 붙이지 않는다(두 번 붙지 않음)', (tester) async {
    final show = ValueNotifier(true);
    await pump(tester, show: show);
    await tester.tap(find.byKey(RecordingScreen.stopKey));
    await waitUntil(tester, () => popped);
    show.value = false;
    await tester.pump();
    await idle(tester);
    expect(rec.stopped, 1);
    expect(actions.attached, isEmpty, reason: '결과는 편집 화면이 붙인다');
  });

  testWidgets('녹음을 시작하지 못한 채 사라지면 붙일 것이 없다', (tester) async {
    final show = ValueNotifier(true);
    await pump(tester, permitted: false, show: show);
    show.value = false;
    await tester.pump();
    await idle(tester);
    expect(actions.attached, isEmpty);
  });
}
