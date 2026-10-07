import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/button_semantics.dart';
import '../../data/transcription_service.dart';
import '../../domain/guidance_models.dart';
import '../../domain/transcript.dart';
import '../providers/guidance_providers.dart';
import '../widgets/audio_playback.dart';

/// 녹음 한 개를 기기 안에서 받아 적어 보여 준다(참고용). **저장하지 않는다** — 화면을 닫으면 사라진다.
/// 재생기는 이 화면에 하나뿐이고, 시각 칩·글 없음 줄이 그 위치로 옮겨 재생한다.
class GuidanceTranscriptScreen extends ConsumerStatefulWidget {
  const GuidanceTranscriptScreen({super.key, required this.recordId, required this.attachmentId});

  final int recordId;
  final int attachmentId;

  static const copyAllKey = Key('transcript_copy_all');
  static const retryKey = Key('transcript_retry');
  static const progressKey = Key('transcript_progress');
  static const preparingKey = Key('transcript_preparing');
  static const playKey = Key('transcript_play');
  static Key chipKey(int index) => Key('transcript_chip_$index');
  static Key copyKey(int index) => Key('transcript_copy_$index');
  static Key gapKey(int startMs) => Key('transcript_gap_$startMs');

  @override
  ConsumerState<GuidanceTranscriptScreen> createState() => _GuidanceTranscriptScreenState();
}

class _GuidanceTranscriptScreenState extends ConsumerState<GuidanceTranscriptScreen>
    with WidgetsBindingObserver {
  final _segments = <TranscriptSegment>[];

  /// 문단이 들어올 때만 다시 계산한다 — 재생 위치는 초당 여러 번 오므로 그때마다 정렬하지 않는다.
  var _visible = const <TranscriptSegment>[];
  var _items = const <TranscriptItem>[];
  StreamSubscription<TranscriptEvent>? _sub;
  AudioPlayback? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playingSub;
  File? _file;
  int? _durationMs;
  var _missing = false;
  var _preparing = false;
  var _done = false;
  TranscriptFailure? _failure;
  /// 재생 위치는 플레이어 카드만 다시 그린다. 목록은 재생 중인 문단([_active])이 바뀔 때만.
  final _position = ValueNotifier<int>(0);
  int? _active;
  var _playing = false;

  /// 첨부 목록은 autoDispose라 `.future`를 읽는 동안 리스너가 없으면 버려진다 — 화면 수명 동안 붙잡는다.
  late final ProviderSubscription<AsyncValue<List<GuidanceAttachment>>> _keepAttachments;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keepAttachments = ref.listenManual(guidanceAttachmentsProvider(widget.recordId), (_, _) {});
    _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 첨부 줄과 같은 규칙 — 떠나거나 잠기면 소리를 멈춘다. 전사는 그대로 둔다.
    if (state != AppLifecycleState.resumed && _playing) {
      unawaited(_player?.pause().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAttachments.close();
    _sub?.cancel();
    _posSub?.cancel();
    _playingSub?.cancel();
    _player?.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final attachments = await ref.read(guidanceAttachmentsProvider(widget.recordId).future);
    GuidanceAttachment? a;
    for (final x in attachments) {
      if (x.id == widget.attachmentId) a = x;
    }
    final file = a == null ? null : await ref.read(guidanceFileStoreProvider).fileOf(a.fileName);
    final exists = file != null && await file.exists();
    if (!mounted) return;
    setState(() {
      _file = file;
      _durationMs = a?.durationMs;
      _missing = !exists;
    });
    if (exists) _listen(file.path);
  }

  void _listen(String path) {
    _sub?.cancel();
    setState(() {
      _segments.clear();
      _visible = const [];
      _items = const [];
      _done = false;
      _failure = null;
      _preparing = false;
    });
    _sub = ref.read(transcriptionServiceProvider).transcribe(path).listen(
      (e) {
        if (!mounted) return;
        setState(() {
          switch (e) {
            case TranscriptPreparing():
              _preparing = true;
            case TranscriptSegmentArrived(:final segment):
              _preparing = false;
              _segments.add(segment);
              _visible = cleanSegments(_segments);
              _items = buildTranscriptView(_segments);
              _active = activeSegmentIndex(_visible, _position.value);
          }
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _preparing = false;
          _done = true;
          _failure = e is TranscriptionException ? e.failure : TranscriptFailure.other;
        });
      },
      onDone: () {
        if (mounted) setState(() => _done = true);
      },
    );
  }

  AudioPlayback _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = ref.read(audioPlaybackFactoryProvider)();
    _posSub = p.position.listen((d) {
      if (mounted) _moveTo(d.inMilliseconds);
    });
    _playingSub = p.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    });
    return _player = p;
  }

  void _moveTo(int ms) {
    _position.value = ms;
    final active = activeSegmentIndex(_visible, ms);
    if (active != _active) setState(() => _active = active);
  }

  Future<void> _playFrom(int ms) async {
    final file = _file;
    if (file == null || _missing) return;
    _moveTo(ms);
    await _ensurePlayer().playFrom(file.path, Duration(milliseconds: ms));
  }

  Future<void> _togglePlay() async {
    final file = _file;
    if (file == null || _missing) return;
    final p = _ensurePlayer();
    if (_playing) {
      await p.pause();
    } else {
      await p.playFrom(file.path, Duration(milliseconds: _position.value));
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    // 상수 문구만 — 스낵바는 잠금 덮개 밖에 남는다.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text(GuidanceStrings.transcriptCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final items = _items;
    final canCopyAll = _done && visible.isNotEmpty;
    final header = <Widget>[
      _playerCard(),
      if (!_done) _progress(visible),
      if (_preparing) _preparingBox(),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
        child: Text(GuidanceStrings.transcriptNotice, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
      ),
    ];
    final footer = <Widget>[
      if (_done && _failure == null && visible.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSizes.spacing20),
          child: Text(GuidanceStrings.transcriptEmpty, textAlign: TextAlign.center, style: AppTextStyles.bodyM),
        ),
      if (_failure case final failure?) _failureBox(failure),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(GuidanceStrings.transcriptTitle),
            const SizedBox(width: AppSizes.spacing8),
            _Tag(),
          ],
        ),
        actions: [
          TextButton(
            key: GuidanceTranscriptScreen.copyAllKey,
            onPressed: canCopyAll ? () => _copy(formatTranscriptForCopy(_segments)) : null,
            child: const Text(GuidanceStrings.transcriptCopyAll),
          ),
        ],
      ),
      body: _missing
          ? Center(child: Text(GuidanceStrings.attachmentMissing, style: AppTextStyles.bodyM))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spacing16, AppSizes.spacing8, AppSizes.spacing16, AppSizes.spacing20),
              itemCount: header.length + items.length + footer.length,
              itemBuilder: (context, i) {
                if (i < header.length) return header[i];
                final k = i - header.length;
                if (k >= items.length) return footer[k - items.length];
                return switch (items[k]) {
                  TranscriptParagraph(:final segment, :final index) => _paragraph(index, segment, index == _active),
                  TranscriptGap(:final startMs, :final lengthMs) => _gap(startMs, lengthMs),
                };
              },
            ),
    );
  }

  Widget _playerCard() {
    final total = _durationMs;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        side: BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        child: Row(
          children: [
            IconButton.filled(
              key: GuidanceTranscriptScreen.playKey,
              style: IconButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white),
              onPressed: _togglePlay,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow,
                  semanticLabel: _playing ? GuidanceStrings.pause : GuidanceStrings.play),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _position,
                builder: (context, positionMs, _) {
                  final ratio = total == null || total <= 0 ? null : (positionMs / total).clamp(0.0, 1.0);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ratio != null)
                        LinearProgressIndicator(value: ratio, color: AppColors.gold, backgroundColor: AppColors.line),
                      const SizedBox(height: AppSizes.spacing4),
                      Text(
                        total == null
                            ? formatTranscriptTime(positionMs)
                            : '${formatTranscriptTime(positionMs)} / ${formatTranscriptTime(total)}',
                        style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress(List<TranscriptSegment> visible) {
    final total = _durationMs;
    final reached = visible.isEmpty ? 0 : visible.last.endMs;
    final ratio = total == null || total <= 0 ? null : (reached / total).clamp(0.0, 1.0);
    return Padding(
      key: GuidanceTranscriptScreen.progressKey,
      padding: const EdgeInsets.only(top: AppSizes.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            total == null
                ? GuidanceStrings.transcriptProgress
                : '${GuidanceStrings.transcriptProgress}  ${formatTranscriptTime(reached)} / ${formatTranscriptTime(total)}',
            style: AppTextStyles.bodyS.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSizes.spacing4),
          // 길이를 모르면 값 없는 막대(왕복 애니메이션) — 0으로 나누지 않는다.
          LinearProgressIndicator(value: ratio, color: AppColors.gold, backgroundColor: AppColors.line),
          const SizedBox(height: AppSizes.spacing4),
          Text(GuidanceStrings.transcriptProgressNotice,
              style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
        ],
      ),
    );
  }

  Widget _preparingBox() => Container(
    key: GuidanceTranscriptScreen.preparingKey,
    margin: const EdgeInsets.only(top: AppSizes.spacing8),
    padding: const EdgeInsets.all(AppSizes.spacing12),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppSizes.radius12),
    ),
    child: Text(GuidanceStrings.transcriptPreparing, style: AppTextStyles.bodyS),
  );

  Widget _paragraph(int index, TranscriptSegment s, bool active) {
    final time = formatTranscriptTime(s.startMs);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          side: BorderSide(color: active ? AppColors.goldFill : AppColors.line, width: active ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ButtonSemantics(
                    label: GuidanceStrings.transcriptPlayFrom(time),
                    onTap: () => _playFrom(s.startMs),
                    child: InkWell(
                      key: GuidanceTranscriptScreen.chipKey(index),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      onTap: () => _playFrom(s.startMs),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 32),
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing12),
                        decoration: BoxDecoration(
                          color: active ? AppColors.goldFill : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 색만으로 두지 않는다 — 재생 중이면 모양도 바뀐다.
                            Icon(active && _playing ? Icons.pause : Icons.play_arrow,
                                size: 14, color: active ? AppColors.onGold : AppColors.ink),
                            const SizedBox(width: AppSizes.spacing4),
                            Text(time,
                                style: AppTextStyles.bodyS.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: active ? AppColors.onGold : AppColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: GuidanceTranscriptScreen.copyKey(index),
                    onPressed: () => _copy(s.text.trim()),
                    child: const Text(GuidanceStrings.transcriptCopy),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacing4),
              SelectableText(s.text.trim(), style: AppTextStyles.bodyM.copyWith(height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gap(int startMs, int lengthMs) {
    final label = GuidanceStrings.transcriptGap(formatTranscriptTime(startMs), lengthMs ~/ 1000);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
      child: OutlinedButton.icon(
        key: GuidanceTranscriptScreen.gapKey(startMs),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(40),
          foregroundColor: AppColors.sub,
          side: BorderSide(color: AppColors.line),
        ),
        onPressed: () => _playFrom(startMs),
        icon: const Icon(Icons.play_arrow, size: 14),
        label: Text(label, style: AppTextStyles.bodyS),
      ),
    );
  }

  Widget _failureBox(TranscriptFailure failure) {
    final (text, canRetry) = switch (failure) {
      TranscriptFailure.modelDownload => (GuidanceStrings.transcriptModelFailed, true),
      TranscriptFailure.fileNotFound => (GuidanceStrings.attachmentMissing, false),
      TranscriptFailure.unsupported || TranscriptFailure.other => (GuidanceStrings.transcriptFailed, true),
    };
    final file = _file;
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacing12),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center,
              style: AppTextStyles.bodyM.copyWith(color: AppColors.error)),
          if (canRetry && file != null)
            TextButton(
              key: GuidanceTranscriptScreen.retryKey,
              onPressed: () => _listen(file.path),
              child: const Text(GuidanceStrings.transcriptRetry),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.sub),
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
    ),
    child: Text(GuidanceStrings.transcribeTag,
        style: AppTextStyles.bodyS.copyWith(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w600)),
  );
}
