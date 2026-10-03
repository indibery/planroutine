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
                result = await Navigator.of(
                  context,
                ).push<RecordingResult>(MaterialPageRoute(builder: (_) => const RecordingScreen(title: '복도 다툼')));
                popped = true;
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await waitUntil(
      tester,
      () => permitted
          ? find.text(GuidanceStrings.recordingLive).evaluate().isNotEmpty
          : find.text(GuidanceStrings.micDenied).evaluate().isNotEmpty,
    );
  }

  testWidgets('허락하면 첨부 폴더 안에 녹음하고, 멈추면 결과를 돌려준다', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.recordingLive), findsOneWidget);
    expect(find.text(GuidanceStrings.recordingLegal), findsOneWidget);
    expect(find.text(GuidanceStrings.recordingNotice), findsOneWidget);
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
}
