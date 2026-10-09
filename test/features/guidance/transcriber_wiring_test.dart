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
    expect(
      RegExp(r'Transcriber\.swift in Sources').allMatches(pbx).length,
      2,
      reason: 'PBXBuildFile 1 + Sources 단계 1',
    );
  });

  test('Swift에 저장 경로가 없다 — 전사문은 저장하지 않는다', () {
    for (final banned in [
      'UserDefaults',
      'write(to',
      'FileManager.default.createFile',
    ]) {
      expect(swift, isNot(contains(banned)), reason: banned);
    }
  });

  test('분석이 오류로 끝나도 수집 작업을 취소하고 분석기를 끝낸다 — 다시 시도마다 모델이 쌓이지 않게', () {
    // 취소 처리기는 취소될 때만 돈다. 손상된 녹음에서 분석기가 던지면 그 경로가 따로 정리해야 한다(최종 검토 지적).
    final body = swift.substring(swift.indexOf('let collector = Task'));
    final catchBlock = RegExp(r'\}\s*catch\s*\{([^}]*)\}').firstMatch(body)?.group(1) ?? '';
    expect(catchBlock, contains('collector.cancel()'));
    expect(catchBlock, contains('cancelAndFinishNow()'));
  });

  test('시각이 NaN·무한이면 정수로 바꾸지 않는다 — Int 변환이 앱을 멈추게 한다', () {
    expect(swift, contains('isFinite'));
    expect(swift, isNot(contains('Int(result.range.start.seconds')), reason: '검사 없이 바로 바꾸면 안 된다');
  });

  test('이전 구독의 늦은 문단은 버린다 — 화면을 떠난 직후 다음 화면에 섞이지 않게', () {
    // 취소 확인과 메인 큐 전달 사이에 문단이 실려 있으면 다음 구독의 싱크로 갈 수 있었다(최종 검토 지적).
    expect(swift, contains('generation'));
    final listen = swift.substring(swift.indexOf('func onListen'), swift.indexOf('func onCancel'));
    expect(listen, contains('generation'));
  });
}
