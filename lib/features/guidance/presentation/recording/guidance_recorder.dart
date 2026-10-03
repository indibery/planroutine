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

  /// 권한 창도 앱을 비활성으로 만든다 — 가드로 감싸야 녹음 중단이 일어나지 않는다.
  @override
  Future<bool> ensurePermission() => SystemSheetGuard.run(() => _recorder.hasPermission());

  @override
  Future<void> start(String path) async {
    await WakelockPlus.enable();
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
        path: path,
      );
    } catch (_) {
      // 시작에 실패하면 화면을 켜 둘 이유가 없다 — 켠 것을 도로 끄고 호출부가 안내하게 넘긴다.
      await WakelockPlus.disable();
      rethrow;
    }
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

final guidanceRecorderFactoryProvider = Provider<GuidanceRecorder Function()>((ref) => RecordGuidanceRecorder.new);
