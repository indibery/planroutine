import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 지금 녹음 중인 파일 — 녹음을 시작할 때 남기고, 기록에 붙으면 지운다.
class RecordingMarker {
  const RecordingMarker({
    required this.recordId,
    required this.fileName,
    required this.startedAt,
  });

  final int recordId;

  /// 첨부 폴더 안의 파일 이름(경로가 아니다 — 앱 폴더 경로는 설치마다 바뀔 수 있다).
  final String fileName;
  final DateTime startedAt;
}

/// "녹음 중" 표시. 방전·강제 종료처럼 앱이 마무리할 틈 없이 꺼지면 이 표시가 남고,
/// 다음에 앱을 열 때 그 파일을 기록에 붙인다(`GuidanceActions.recoverInterruptedRecording`).
///
/// 기록 내용은 넣지 않는다 — 기록 번호와 파일 이름, 시작 시각뿐이다.
class RecordingMarkerStore {
  static const prefsKey = 'guidance_recording_in_progress_v1';

  Future<void> save(RecordingMarker m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      jsonEncode({
        'recordId': m.recordId,
        'fileName': m.fileName,
        'startedAt': m.startedAt.toIso8601String(),
      }),
    );
  }

  /// 망가진 값이면 없는 것으로 본다.
  Future<RecordingMarker?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final startedAt = DateTime.tryParse(m['startedAt'] as String? ?? '');
      final recordId = m['recordId'];
      final fileName = m['fileName'];
      if (startedAt == null || recordId is! int || fileName is! String) {
        return null;
      }
      return RecordingMarker(
        recordId: recordId,
        fileName: fileName,
        startedAt: startedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}
