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
    // 파일 위치를 찾는 I/O(폴더 확인·만들기, 두 단계)는 fake-async 밖에서 끝나야 한다 —
    // 한 번에 한 단계씩만 진행하므로 여러 번 돌린다(3번은 모자랐다).
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
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
    // 타일 제목에도 같은 이름이 있으므로 시트 안만 본다
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('통화 녹음 1002.m4a')),
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
}
