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
  var pauses = 0;
  var disposed = false;
  final _playing = StreamController<bool>.broadcast();
  @override
  Future<void> play(String path) async {
    played.add(path);
    _playing.add(true);
  }

  final playFromCalls = <(String, Duration)>[];
  @override
  Future<void> playFrom(String path, Duration at) async =>
      playFromCalls.add((path, at));

  @override
  Future<void> pause() async {
    pauses++;
    _playing.add(false);
  }

  /// 끝까지 재생됨 — 진짜 재생기는 completed에서 멈추고 되감아 `playing`이 false가 된다.
  void finish() => _playing.add(false);

  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Future<void> dispose() async {
    disposed = true;
    await _playing.close();
  }
}

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  late Directory base;
  late List<FakePlayback> players;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('att_tile');
    players = [];
    final dir = await Directory('${base.path}/guidance').create();
    for (final n in ['r.m4a', 'b.m4a', 'x.png']) {
      await File('${dir.path}/$n').writeAsBytes([0]);
    }
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

  Widget host(GuidanceAttachment a, {VoidCallback? onRemove, VoidCallback? onTranscribe}) => ProviderScope(
    overrides: [
      guidanceFileStoreProvider.overrideWithValue(
        GuidanceFileStore(baseDir: () async => base),
      ),
      audioPlaybackFactoryProvider.overrideWithValue(() {
        final p = FakePlayback();
        players.add(p);
        return p;
      }),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: AttachmentTile(
          attachment: a,
          now: DateTime(2026, 10, 3),
          onRemove: onRemove,
          onTranscribe: onTranscribe,
        ),
      ),
    ),
  );

  /// 파일 위치 찾기·존재 확인은 실제 I/O라 fake-async 밖에서 끝나야 한다.
  /// 고정 시간이 아니라 조건이 될 때까지(상한 40회) 기다린다.
  Future<void> waitUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 40 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    expect(done(), isTrue, reason: '기다리던 상태가 되지 않았다');
  }

  bool playEnabled(WidgetTester tester, int id) {
    final f = find.byKey(AttachmentTile.playKey(id));
    return f.evaluate().isNotEmpty &&
        tester.widget<IconButton>(f).onPressed != null;
  }

  Future<void> pump(
    WidgetTester tester,
    GuidanceAttachment a, {
    VoidCallback? onRemove,
    VoidCallback? onTranscribe,
  }) async {
    await tester.pumpWidget(host(a, onRemove: onRemove, onTranscribe: onTranscribe));
    if (a.type == AttachmentType.audio) {
      await waitUntil(tester, () => playEnabled(tester, a.id ?? -1));
    } else {
      await waitUntil(tester, () => find.byType(Image).evaluate().isNotEmpty);
    }
  }

  Future<void> tapPlay(WidgetTester tester, int id) async {
    await tester.tap(find.byKey(AttachmentTile.playKey(id)));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }

  testWidgets('녹음은 길이·출처를 보여 주고 누르면 그 파일을 재생한다', (tester) async {
    await pump(tester, audio);
    expect(find.textContaining('12:48'), findsOneWidget);
    expect(find.textContaining(GuidanceStrings.sourceRecorded), findsOneWidget);
    await tapPlay(tester, 1);
    expect(players.single.played.single.endsWith('r.m4a'), isTrue);
  });

  testWidgets('정보를 누르면 해시와 원래 이름이 보인다', (tester) async {
    await pump(
      tester,
      audio.copyWith(
        source: AttachmentSource.imported,
        originalName: '통화 녹음 1002.m4a',
      ),
    );
    await tester.tap(find.byKey(AttachmentTile.infoKey(1)));
    await tester.pumpAndSettle();
    expect(find.text(audio.sha256), findsOneWidget);
    // 타일 제목에도 같은 이름이 있으므로 시트 안만 본다
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('통화 녹음 1002.m4a'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('빼기 버튼은 onRemove가 있을 때만 보인다', (tester) async {
    await pump(tester, audio);
    expect(find.byKey(AttachmentTile.removeKey(1)), findsNothing);
    var removed = false;
    await pump(tester, audio, onRemove: () => removed = true);
    await tester.tap(find.byKey(AttachmentTile.removeKey(1)));
    expect(removed, isTrue);
  });

  testWidgets('재생 → 멈춤 → 재생으로 토글한다', (tester) async {
    await pump(tester, audio);
    await tapPlay(tester, 1);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    await tapPlay(tester, 1);
    expect(players.single.pauses, 1);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tapPlay(tester, 1);
    expect(players.single.played, hasLength(2));
  });

  testWidgets('끝까지 재생된 뒤 다시 누르면 처음부터 다시 재생한다', (tester) async {
    await pump(tester, audio);
    await tapPlay(tester, 1);
    players.single.finish();
    await tester.pump();
    expect(
      find.byIcon(Icons.play_arrow),
      findsOneWidget,
      reason: '끝나면 버튼이 재생으로 돌아온다',
    );
    await tapPlay(tester, 1);
    expect(players.single.played, hasLength(2));
  });

  testWidgets('타일이 트리에서 빠지면 재생기를 정리한다', (tester) async {
    await pump(tester, audio);
    await tapPlay(tester, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(players.single.disposed, isTrue);
  });

  testWidgets('같은 자리에 다른 첨부가 들어오면 옛 재생기를 버리고 새 파일을 재생한다', (tester) async {
    await pump(tester, audio);
    await tapPlay(tester, 1);
    final other = audio.copyWith(id: 2, fileName: 'b.m4a');
    await tester.pumpWidget(host(other));
    expect(players.first.disposed, isTrue);
    await waitUntil(tester, () => playEnabled(tester, 2));
    expect(
      find.byIcon(Icons.play_arrow),
      findsOneWidget,
      reason: '재생 상태도 새로 시작한다',
    );
    await tapPlay(tester, 2);
    expect(players.last.played.single.endsWith('b.m4a'), isTrue);
  });

  testWidgets('파일이 없으면 안내하고 재생 버튼은 눌리지 않는다', (tester) async {
    await tester.pumpWidget(host(audio.copyWith(fileName: 'gone.m4a')));
    await waitUntil(
      tester,
      () => find
          .textContaining(GuidanceStrings.attachmentMissing)
          .evaluate()
          .isNotEmpty,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(AttachmentTile.playKey(1)))
          .onPressed,
      isNull,
    );
    expect(players, isEmpty);
  });

  testWidgets('재생기가 실패하면 같은 안내를 스낵바로 띄운다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceFileStoreProvider.overrideWithValue(
            GuidanceFileStore(baseDir: () async => base),
          ),
          audioPlaybackFactoryProvider.overrideWithValue(
            () => throw StateError('플러그인 실패'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AttachmentTile(attachment: audio, now: DateTime(2026, 10, 3)),
          ),
        ),
      ),
    );
    await waitUntil(tester, () => playEnabled(tester, 1));
    await tester.tap(find.byKey(AttachmentTile.playKey(1)));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(GuidanceStrings.attachmentMissing), findsOneWidget);
  });

  testWidgets('앱을 떠나거나 잠기면(resumed가 아니면) 재생을 멈춘다', (tester) async {
    await pump(tester, audio);
    await tapPlay(tester, 1);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(players.single.pauses, 1);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    // 이미 멈췄으니 이어지는 단계에서 또 멈추지 않는다.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(players.single.pauses, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(players.single.played, hasLength(1), reason: '돌아와도 저절로 다시 재생하지 않는다');
  });

  testWidgets('재생 중이 아니면 생명주기에 반응하지 않는다', (tester) async {
    await pump(tester, audio);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(players, isEmpty, reason: '재생기를 만들지도 않는다');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

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
}
