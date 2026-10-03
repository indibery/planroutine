import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../lock/system_sheet_guard.dart';
import '../providers/guidance_providers.dart';
import 'guidance_recorder.dart';

class RecordingResult {
  const RecordingResult({required this.path, required this.durationMs, required this.startedAt});
  final String path;
  final int durationMs;
  final DateTime startedAt;
}

enum _Phase { checking, denied, recording }

/// 녹음 화면. 녹음 동안 화면이 꺼지지 않고, **앱을 떠나거나 전화가 오거나 뒤로 가면
/// 그때까지 저장해 결과를 돌려준다** — 녹음을 버리는 길이 없다.
class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key, required this.title});

  final String title;

  static const stopKey = Key('recording_stop');
  static const settingsKey = Key('recording_settings');

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> with WidgetsBindingObserver {
  late final GuidanceRecorder _recorder = ref.read(guidanceRecorderFactoryProvider)();
  var _phase = _Phase.checking;
  String? _path;
  DateTime? _startedAt;
  Timer? _ticker;
  var _elapsed = Duration.zero;
  var _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _begin();
  }

  Future<void> _begin() async {
    final ok = await _recorder.ensurePermission();
    if (!mounted) return;
    if (!ok) {
      setState(() => _phase = _Phase.denied);
      return;
    }
    final path = await ref.read(guidanceFileStoreProvider).newRecordingPath();
    // 경로를 얻는 동안 이미 닫혔으면(화면이 사라졌거나 마무리 중) 녹음을 시작하지 않는다.
    if (!mounted || _finishing) {
      return;
    }
    await _recorder.start(path);
    if (!mounted) return;
    final started = DateTime.now();
    setState(() {
      _path = path;
      _startedAt = started;
      _phase = _Phase.recording;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(started));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.detached) {
      return;
    }
    if (SystemSheetGuard.shouldIgnore(state)) return;
    _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _ticker?.cancel();
    final path = _path;
    final started = _startedAt;
    if (path == null || started == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // 멈추는 호출이 실패해도 파일은 첨부 폴더에 있다 — 녹음을 버리지 않고 그 경로로 돌려준다.
    var out = path;
    try {
      out = await _recorder.stop() ?? path;
    } catch (_) {}
    final ms = DateTime.now().difference(started).inMilliseconds;
    if (mounted) {
      Navigator.of(context).pop(RecordingResult(path: out, durationMs: ms, startedAt: started));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String get _clock {
    final s = _elapsed.inSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '${m.toString().padLeft(2, '0')}:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final on = AppColors.onRecording;
    return PopScope(
      canPop: _phase != _Phase.recording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: AppColors.recordingBackground,
        appBar: AppBar(
          backgroundColor: AppColors.recordingBackground,
          foregroundColor: on,
          automaticallyImplyLeading: _phase != _Phase.recording,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spacing24),
            child: switch (_phase) {
              _Phase.checking => const SizedBox.shrink(),
              _Phase.denied => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_off, size: 48, color: on),
                  const SizedBox(height: AppSizes.spacing12),
                  Text(
                    GuidanceStrings.micDenied,
                    style: TextStyle(color: on, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  Text(
                    GuidanceStrings.micDeniedBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: on, fontSize: 15),
                  ),
                  const SizedBox(height: AppSizes.spacing20),
                  FilledButton(
                    key: RecordingScreen.settingsKey,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.goldFill,
                      foregroundColor: AppColors.onGold,
                    ),
                    onPressed: openAppSettings,
                    child: const Text(GuidanceStrings.openSettings),
                  ),
                ],
              ),
              _Phase.recording => Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, size: 10, color: AppColors.recordingLive),
                      const SizedBox(width: AppSizes.spacing8),
                      Text(
                        GuidanceStrings.recordingLive,
                        style: TextStyle(color: AppColors.recordingLive, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  Text(
                    widget.title,
                    style: TextStyle(color: on, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    _clock,
                    style: TextStyle(
                      color: on,
                      fontSize: 64,
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: GuidanceStrings.recordingStop,
                    child: InkResponse(
                      key: RecordingScreen.stopKey,
                      onTap: _finish,
                      radius: 48,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: on, width: 3),
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.recordingLive,
                              borderRadius: BorderRadius.circular(AppSizes.radius4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  Text(GuidanceStrings.recordingStopHint, style: TextStyle(color: on, fontSize: 14)),
                  const Spacer(),
                  Text(
                    GuidanceStrings.recordingLegal,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: on, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: AppSizes.spacing4),
                  Text(
                    GuidanceStrings.recordingNotice,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: on, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: AppSizes.spacing12),
                  Text(
                    GuidanceStrings.recordingScreenOn,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: on, fontSize: 13),
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}
