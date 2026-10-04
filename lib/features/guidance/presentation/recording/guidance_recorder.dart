import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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

/// AAC 모노 64kbps(1시간 약 30MB)를 **ADTS 스트림으로 받아 앱이 직접 파일에 쓴다.**
///
/// `.m4a`는 녹음을 멈출 때 목차를 맨 끝에 써서 파일을 완성한다. 방전·강제 종료로 끊기면 파일은
/// 남아도 재생되지 않는다(iOS `AVAudioRecorder`, Android `MediaMuxer` 모두 그렇다). ADTS는 프레임마다
/// 머리말이 있어 그때까지 쓴 데까지 재생된다 — 그래서 플러그인의 파일 녹음 대신 스트림을 받아
/// 1초마다 디스크로 밀어 넣는다(2026-10-04 사용자 결정). 용량은 2~4% 늘어난다(프레임 머리말 7바이트).
///
/// 녹음 동안 화면을 켜 둔다 — 백그라운드 녹음은 하지 않으므로 화면이 꺼지면 녹음이 멈춘다(스펙 결정 A).
class RecordGuidanceRecorder implements GuidanceRecorder {
  final _recorder = AudioRecorder();

  RandomAccessFile? _file;
  StreamSubscription<Uint8List>? _sub;
  Completer<void>? _done;
  var _lastFlush = DateTime.now();

  /// 권한 창도 앱을 비활성으로 만든다 — 가드로 감싸야 녹음 중단이 일어나지 않는다.
  @override
  Future<bool> ensurePermission() => SystemSheetGuard.run(() => _recorder.hasPermission());

  @override
  Future<void> start(String path) async {
    await WakelockPlus.enable();
    try {
      final file = await File(path).open(mode: FileMode.write);
      _file = file;
      final done = Completer<void>();
      _done = done;
      final stream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
      );
      _lastFlush = DateTime.now();
      _sub = stream.listen(
        (chunk) {
          // 동기 쓰기 — 앱이 꺼져도 운영체제에 넘어간 바이트는 남는다. 1초마다 디스크까지 밀어 넣는다.
          file.writeFromSync(chunk);
          final now = DateTime.now();
          if (now.difference(_lastFlush) >= const Duration(seconds: 1)) {
            file.flushSync();
            _lastFlush = now;
          }
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        onError: (Object _) {
          if (!done.isCompleted) done.complete();
        },
      );
    } catch (_) {
      // 시작에 실패하면 화면을 켜 둘 이유가 없다 — 켠 것을 도로 끄고 호출부가 안내하게 넘긴다.
      await _closeFile();
      await WakelockPlus.disable();
      rethrow;
    }
  }

  @override
  Future<String?> stop() async {
    final path = _file?.path;
    try {
      await _recorder.stop();
      // 남은 바이트가 흘러오고 스트림이 닫힐 때까지 기다린다(닫히지 않아도 2초 뒤에는 마무리한다).
      await _done?.future.timeout(const Duration(seconds: 2), onTimeout: () {});
      return path;
    } finally {
      await _sub?.cancel();
      _sub = null;
      await _closeFile();
      await WakelockPlus.disable();
    }
  }

  Future<void> _closeFile() async {
    final f = _file;
    _file = null;
    if (f == null) return;
    try {
      f.flushSync();
      await f.close();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await WakelockPlus.disable();
    await _sub?.cancel();
    await _closeFile();
    await _recorder.dispose();
  }
}

final guidanceRecorderFactoryProvider = Provider<GuidanceRecorder Function()>((ref) => RecordGuidanceRecorder.new);
