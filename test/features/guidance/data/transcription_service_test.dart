import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/data/transcription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
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
    expect(
      await ChannelTranscriptionService(isAndroid: true).isAvailable(),
      isFalse,
    );
    expect(called, isFalse);
  });

  test('iOS면 채널 답을 그대로, 채널 오류는 false', () async {
    messenger.setMockMethodCallHandler(method, (_) async => true);
    expect(
      await ChannelTranscriptionService(isAndroid: false).isAvailable(),
      isTrue,
    );
    messenger.setMockMethodCallHandler(
      method,
      (_) async => throw PlatformException(code: 'x'),
    );
    expect(
      await ChannelTranscriptionService(isAndroid: false).isAvailable(),
      isFalse,
    );
  });

  test('이벤트를 준비·문단으로 바꾸고 경로를 인자로 넘긴다', () async {
    Object? gotArgs;
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          gotArgs = args;
          sink.success({'type': 'preparing'});
          sink.success({
            'type': 'segment',
            'startMs': 0,
            'endMs': 1500,
            'text': '안녕',
          });
          sink.endOfStream();
        },
      ),
    );
    final out = await ChannelTranscriptionService(
      isAndroid: false,
    ).transcribe('/a.aac').toList();
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
        emitsError(
          isA<TranscriptionException>().having(
            (e) => e.failure,
            'failure',
            failure,
          ),
        ),
      );
    }
  });
}
