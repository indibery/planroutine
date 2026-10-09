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
  var failPlay = false;
  final _pos = StreamController<Duration>.broadcast();
  void emit(Duration d) => _pos.add(d);
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> playFrom(String path, Duration at) async {
    if (failPlay) throw StateError('재생 실패');
    playFromCalls.add(at);
  }
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
  var attachmentLoads = 0;
  var failAttachmentLoad = false;
  late FakePlayback playback;
  late List<String?> clipboard;
  late Directory base;

  // 첨부 줄 테스트와 같은 방법 — 실제 파일 저장소에 임시 폴더를 준다(`guidance/a.aac`).
  setUp(() async {
    base = await Directory.systemTemp.createTemp('transcript_test');
    await Directory('${base.path}/guidance').create();
    await File('${base.path}/guidance/a.aac').writeAsBytes([0]);
    service = FakeService();
    attachmentLoads = 0;
    failAttachmentLoad = false;
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
          guidanceAttachmentsProvider(1).overrideWith((ref) async {
            attachmentLoads++;
            if (failAttachmentLoad) throw StateError('불러오기 실패');
            return [audio(durationMs: durationMs)];
          }),
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
    // 화면 전환을 끝낸다 — 진행 막대가 계속 움직여 pumpAndSettle은 끝나지 않는다.
    await tester.pump(const Duration(seconds: 1));
  }

  /// 화면은 실제 파일 확인(`runAsync`) 뒤에 구독하므로 이벤트가 실제 시간 영역에서 온다 —
  /// 한 번 흘려 보낸 뒤 그린다(첨부 줄 테스트의 waitUntil과 같은 이유).
  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  testWidgets('문단이 오는 대로 쌓이고, 전사 중에는 전체 복사가 꺼진다', (tester) async {
    await pump(tester);
    expect(find.byKey(GuidanceTranscriptScreen.progressKey), findsOneWidget);
    service.seg(0, 5000, '첫 문단');
    await flush(tester);
    expect(find.text('첫 문단'), findsOneWidget);
    final copyAll = tester.widget<TextButton>(find.byKey(GuidanceTranscriptScreen.copyAllKey));
    expect(copyAll.onPressed, isNull);
    service.seg(15000, 20000, '둘째 문단');
    await service.controller.close();
    await flush(tester);
    expect(find.text('둘째 문단'), findsOneWidget);
    expect(find.byKey(GuidanceTranscriptScreen.progressKey), findsNothing);
    expect(find.byKey(GuidanceTranscriptScreen.gapKey(5000)), findsOneWidget);
    expect(find.text(GuidanceStrings.transcriptGap('00:05', GuidanceStrings.gapLength(10000))), findsOneWidget);
  });

  testWidgets('시각 칩과 글 없음 줄은 그 위치부터 재생한다', (tester) async {
    await pump(tester);
    service.seg(0, 5000, '가');
    service.seg(15000, 20000, '나');
    await service.controller.close();
    await flush(tester);
    await tester.tap(find.byKey(GuidanceTranscriptScreen.chipKey(1)));
    await tester.tap(find.byKey(GuidanceTranscriptScreen.gapKey(5000)));
    await flush(tester);
    expect(playback.playFromCalls, [const Duration(seconds: 15), const Duration(seconds: 5)]);
  });

  testWidgets('복사·전체 복사 — 스낵바에는 글 내용이 없다', (tester) async {
    await pump(tester);
    service.seg(0, 5000, '비밀 발언');
    await service.controller.close();
    await flush(tester);
    await tester.tap(find.byKey(GuidanceTranscriptScreen.copyKey(0)));
    await flush(tester);
    await tester.tap(find.byKey(GuidanceTranscriptScreen.copyAllKey));
    await flush(tester);
    expect(clipboard, ['비밀 발언', '[00:00] 비밀 발언']);
    final snack = find.byType(SnackBar);
    expect(snack, findsWidgets);
    expect(find.descendant(of: snack.first, matching: find.textContaining('비밀')), findsNothing);
    expect(find.text(GuidanceStrings.transcriptCopied), findsWidgets);
  });

  testWidgets('모델 준비 중 안내', (tester) async {
    await pump(tester);
    service.controller.add(const TranscriptPreparing());
    await flush(tester);
    expect(find.byKey(GuidanceTranscriptScreen.preparingKey), findsOneWidget);
    service.seg(0, 1000, '가');
    await flush(tester);
    expect(find.byKey(GuidanceTranscriptScreen.preparingKey), findsNothing);
  });

  testWidgets('문단 0개면 빈 결과 문구', (tester) async {
    await pump(tester);
    await service.controller.close();
    await flush(tester);
    expect(find.text(GuidanceStrings.transcriptEmpty), findsOneWidget);
  });

  testWidgets('모델 실패는 인터넷 안내 + 다시 시도, 받은 문단은 남긴다', (tester) async {
    await pump(tester);
    service.seg(0, 1000, '남는 문단');
    service.controller.addError(const TranscriptionException(TranscriptFailure.modelDownload));
    await flush(tester);
    expect(find.text('남는 문단'), findsOneWidget);
    expect(find.text(GuidanceStrings.transcriptModelFailed), findsOneWidget);
    expect(find.byKey(GuidanceTranscriptScreen.retryKey), findsOneWidget);
  });

  testWidgets('다시 시도는 처음부터 새로 받아 적는다', (tester) async {
    await pump(tester);
    service.controller.addError(const TranscriptionException(TranscriptFailure.other));
    await flush(tester);
    expect(find.text(GuidanceStrings.transcriptFailed), findsOneWidget);
    await tester.tap(find.byKey(GuidanceTranscriptScreen.retryKey));
    await flush(tester);
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
    await flush(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(GuidanceTranscriptScreen.progressKey), findsOneWidget);
  });

  testWidgets('전사 중 뒤로 가면 구독을 끊고 예외가 없다', (tester) async {
    await pump(tester);
    service.seg(0, 1000, '가');
    await flush(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(service.cancelled, isTrue);
    service.controller.add(TranscriptSegmentArrived(
      const TranscriptSegment(startMs: 2000, endMs: 3000, text: '늦게 온 것'),
    ));
    await flush(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('같은 내용의 문단도 칩이 따로 있다', (tester) async {
    await pump(tester);
    service.seg(0, 1000, '네');
    service.seg(0, 1000, '네');
    await service.controller.close();
    await flush(tester);
    expect(find.byKey(GuidanceTranscriptScreen.chipKey(0)), findsOneWidget);
    expect(find.byKey(GuidanceTranscriptScreen.chipKey(1)), findsOneWidget);
  });

  testWidgets('같은 문단 안에서 재생 위치만 바뀌면 문단 목록을 다시 만들지 않는다', (tester) async {
    // 재생 중에는 위치가 초당 여러 번 온다 — 한 시간 녹음(문단 수백 개)에서 매번 목록을 다시 만들면 버벅인다.
    await pump(tester);
    service.seg(0, 5000, '가');
    service.seg(15000, 20000, '나');
    await service.controller.close();
    await flush(tester);
    await tester.tap(find.byKey(GuidanceTranscriptScreen.chipKey(0)));
    await flush(tester);
    playback.emit(const Duration(milliseconds: 1000));
    await flush(tester);
    final before = tester.widget(find.byType(SelectableText).first);
    playback.emit(const Duration(milliseconds: 1200));
    await flush(tester);
    expect(identical(tester.widget(find.byType(SelectableText).first), before), isTrue);
    expect(find.text('00:01 / 01:10'), findsOneWidget, reason: '재생기 시각은 따라간다');
  });

  group('글 없음 줄 문구', () {
    // 테스트 기본 글꼴은 모든 글자를 정사각형으로 그려 숫자·공백도 한글만큼 넓다 — 실제 앱 글꼴로 잰다.
    setUpAll(() async {
      final bytes = File('assets/fonts/PretendardVariable.ttf').readAsBytesSync();
      await (FontLoader('Pretendard')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    });

    test('길이는 1분 미만이면 초, 넘으면 분(나머지 초)', () {
      expect(GuidanceStrings.gapLength(12000), '12초');
      expect(GuidanceStrings.gapLength(60000), '1분');
      expect(GuidanceStrings.gapLength(90400), '1분 30초');
      expect(GuidanceStrings.gapLength(1260000), '21분');
    });

    test('시각 · 길이 글 없음 · 들어 보기', () {
      expect(GuidanceStrings.transcriptGap('00:38', '12초'), '00:38 · 12초 글 없음 · 들어 보기');
    });

    testWidgets('가장 긴 경우도 375pt에서 한 줄 — 한글이 글자 단위로 쪼개지지 않게', (tester) async {
      // iOS 26 기기의 가장 좁은 폭(375pt) · 1시간 넘는 녹음 · 분과 초가 다 붙는 무음.
      await pump(tester);
      tester.view.physicalSize = const Size(375, 1600);
      service.seg(3600000, 3601000, '가');
      service.seg(3601000 + 1290000, 3601000 + 1291000, '나');
      await service.controller.close();
      await flush(tester);
      final finder = find.text(GuidanceStrings.transcriptGap('1:00:01', GuidanceStrings.gapLength(1290000)));
      expect(finder, findsOneWidget);
      final style = tester.widget<Text>(finder).style;
      final lineHeight = (style?.fontSize ?? 14) * (style?.height ?? 1.0);
      expect(tester.getSize(finder).height, lessThan(lineHeight * 1.5));
    });
  });

  testWidgets('첨부를 불러오다 실패하면 받아 적는 중에 멈추지 않고 다시 시도를 준다', (tester) async {
    failAttachmentLoad = true;
    await pump(tester);
    expect(find.byKey(GuidanceTranscriptScreen.progressKey), findsNothing);
    expect(find.text(GuidanceStrings.transcriptFailed), findsOneWidget);
    failAttachmentLoad = false;
    await tester.tap(find.byKey(GuidanceTranscriptScreen.retryKey));
    // 다시 불러오기에 실제 파일 확인(I/O)이 끼어 있다 — 고정 횟수가 아니라 조건으로 기다린다(상한 40회).
    for (var i = 0; i < 40 && service.listened == 0; i++) {
      await flush(tester);
    }
    expect(attachmentLoads, 2, reason: '다시 시도는 첨부를 다시 불러와야 한다');
    expect(service.listened, 1);
  });

  testWidgets('재생을 열지 못하면 처리되지 않은 오류 대신 파일 없음 안내', (tester) async {
    await pump(tester);
    service.seg(0, 1000, '가');
    await service.controller.close();
    await flush(tester);
    playback.failPlay = true;
    await tester.tap(find.byKey(GuidanceTranscriptScreen.chipKey(0)));
    await flush(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(GuidanceStrings.attachmentMissing), findsOneWidget);
  });

  testWidgets('지원하지 않는 기기 오류에는 다시 시도를 주지 않는다', (tester) async {
    await pump(tester);
    service.controller.addError(const TranscriptionException(TranscriptFailure.unsupported));
    await flush(tester);
    expect(find.text(GuidanceStrings.transcriptFailed), findsOneWidget);
    expect(find.byKey(GuidanceTranscriptScreen.retryKey), findsNothing);
  });
}
