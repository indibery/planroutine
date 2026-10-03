import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

enum _Phase { checking, denied, recording, failed }

/// 녹음 화면. 녹음 동안 화면이 꺼지지 않고, **앱을 떠나거나 전화가 오거나 뒤로 가면
/// 그때까지 저장해 결과를 돌려준다** — 녹음을 버리는 길이 없다.
///
/// ⚠️ 이 화면은 탭의 중첩 내비게이터에 떠서 하단 탭바가 보인다. 녹음 중 다른 탭을 누르거나
/// 외부 CSV 공유로 `/import`에 가면 셸과 함께 **결과를 돌려주지 못하고** dispose된다.
/// 그래서 편집 화면이 녹음 **전에** 기록을 만들어 [recordId]를 넘기고, 그렇게 사라질 때는
/// 이 화면이 직접 멈추고 그 기록에 붙인다(파일만 남는 고아 녹음 방지).
class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key, required this.recordId, required this.title});

  /// 녹음을 붙일 기록. 편집 화면이 녹음을 열기 전에 저장해 둔 것이다.
  final int recordId;
  final String title;

  static const stopKey = Key('recording_stop');
  static const settingsKey = Key('recording_settings');
  static const closeKey = Key('recording_close');

  /// 녹음 화면은 테마와 무관하게 어둡다 — 시스템 바 아이콘은 앱 테마가 아니라 이 화면 기준으로 밝게 둔다.
  static const overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> with WidgetsBindingObserver {
  late final GuidanceRecorder _recorder = ref.read(guidanceRecorderFactoryProvider)();

  /// dispose 뒤에는 `ref`를 쓸 수 없다 — 직접 붙일 때 쓰려고 미리 읽어 둔다.
  late final GuidanceActions _actions;
  late final int _recordId;
  var _phase = _Phase.checking;
  String? _path;
  DateTime? _startedAt;
  Timer? _ticker;
  var _elapsed = Duration.zero;
  var _finishing = false;

  /// 녹음을 멈추는 일은 한 번만 한다 — `_finish`와 dispose가 같은 결과를 나눠 쓴다.
  Future<RecordingResult?>? _stopping;

  @override
  void initState() {
    super.initState();
    _actions = ref.read(guidanceActionsProvider);
    _recordId = widget.recordId;
    WidgetsBinding.instance.addObserver(this);
    _begin();
  }

  Future<void> _begin() async {
    try {
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
    } catch (_) {
      // 권한 확인·경로·시작 어디서 실패해도 빈 화면에 갇히지 않게 안내하고 닫을 수 있게 한다.
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 녹음 중이 아니면 반응하지 않는다 — 권한 거부 화면에서 `설정 열기`를 누르면 앱이 비활성이 되는데
    // 그때 화면이 닫히면 안 된다.
    if (_phase != _Phase.recording) return;
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.detached) {
      return;
    }
    if (SystemSheetGuard.shouldIgnore(state)) return;
    _finish();
  }

  /// 녹음을 멈추고 결과를 만든다. 녹음이 시작되지 않았으면 null. 몇 번 불러도 한 번만 멈춘다.
  Future<RecordingResult?> _stop() => _stopping ??= () async {
    final path = _path;
    final started = _startedAt;
    if (path == null || started == null) return null;
    // 멈추는 호출이 실패해도 파일은 첨부 폴더에 있다 — 녹음을 버리지 않고 그 경로로 돌려준다.
    var out = path;
    try {
      out = await _recorder.stop() ?? path;
    } catch (_) {}
    final ms = DateTime.now().difference(started).inMilliseconds;
    return RecordingResult(path: out, durationMs: ms, startedAt: started);
  }();

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _ticker?.cancel();
    final result = await _stop();
    if (mounted) {
      Navigator.of(context).pop(result);
    } else if (result != null) {
      // 멈추는 사이에 화면이 사라졌다 — 결과를 받을 곳이 없으니 직접 붙인다.
      _attachDirectly(result);
    }
  }

  /// 결과를 돌려주지 못하고 사라질 때 그 기록에 직접 붙인다. 위젯 수명과 무관하게 끝까지 돈다.
  void _attachDirectly(RecordingResult r) {
    unawaited(
      _actions
          .attachRecording(recordId: _recordId, path: r.path, durationMs: r.durationMs, startedAt: r.startedAt)
          .then<void>(
            (_) {},
            // 삼키지 않는다 — 다만 기록 내용은 넣지 않는다(파일 이름만).
            onError: (Object e) => debugPrint('지도 기록 녹음을 붙이지 못함(${r.path.split('/').last}): $e'),
          ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    if (!_finishing && _path != null) {
      // `_finish`를 거치지 않고 사라진다(탭 이동·외부 공유로 셸이 dispose) — 멈추고 직접 붙인다.
      // `_finish`가 이미 돌고 있으면 그쪽이 mounted를 보고 직접 붙이므로 여기서는 하지 않는다.
      _finishing = true;
      unawaited(
        _stop().then((r) {
          if (r != null) _attachDirectly(r);
        }),
      );
    }
    // 녹음기는 멈춘 **뒤에** 버린다 — 멈추는 중에 버리면 파일이 끝까지 쓰이지 않을 수 있다.
    final stopping = _stopping;
    unawaited(stopping == null ? _recorder.dispose() : stopping.whenComplete(_recorder.dispose));
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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: RecordingScreen.overlayStyle,
        child: Scaffold(
          backgroundColor: AppColors.recordingBackground,
          appBar: AppBar(
            backgroundColor: AppColors.recordingBackground,
            foregroundColor: on,
            systemOverlayStyle: RecordingScreen.overlayStyle,
            automaticallyImplyLeading: _phase != _Phase.recording,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spacing24),
              child: switch (_phase) {
                _Phase.checking => const SizedBox.shrink(),
                _Phase.failed => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: on),
                    const SizedBox(height: AppSizes.spacing12),
                    Text(
                      GuidanceStrings.recordingStartFailed,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: on, fontSize: 16),
                    ),
                    const SizedBox(height: AppSizes.spacing20),
                    FilledButton(
                      key: RecordingScreen.closeKey,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.goldFill,
                        foregroundColor: AppColors.onGold,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(GuidanceStrings.recordingClose),
                    ),
                  ],
                ),
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
                      onPressed: () => SystemSheetGuard.run(openAppSettings),
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
      ),
    );
  }
}
