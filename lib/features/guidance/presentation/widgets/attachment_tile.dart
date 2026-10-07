import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../providers/guidance_providers.dart';
import 'attachment_info_sheet.dart';
import 'audio_playback.dart';
import '../../../../shared/widgets/button_semantics.dart';

/// 첨부 한 줄. 녹음은 재생/멈춤, 사진은 썸네일(누르면 전체 화면). ⓘ로 해시·원래 이름을 본다.
class AttachmentTile extends ConsumerStatefulWidget {
  const AttachmentTile({
    super.key,
    required this.attachment,
    required this.now,
    this.onRemove,
    this.onTranscribe,
  });

  final GuidanceAttachment attachment;
  final DateTime now;
  final VoidCallback? onRemove;

  /// 녹음을 글로 보기(참고용 전사). 지원 기기의 기록 보기에서만 넘긴다.
  final VoidCallback? onTranscribe;

  static Key playKey(int id) => Key('att_play_$id');
  static Key infoKey(int id) => Key('att_info_$id');
  static Key removeKey(int id) => Key('att_remove_$id');
  static Key imageKey(int id) => Key('att_image_$id');
  static Key transcribeKey(int id) => Key('att_transcribe_$id');

  @override
  ConsumerState<AttachmentTile> createState() => _AttachmentTileState();
}

/// 앱이 resumed가 아니게 되면(떠남·잠김·시스템 창 — 가드 여부와 무관) 재생을 멈춘다.
/// 잠금 덮개가 화면을 가려도 소리는 계속 나기 때문이다.
class _AttachmentTileState extends ConsumerState<AttachmentTile> with WidgetsBindingObserver {
  AudioPlayback? _player;
  StreamSubscription<bool>? _sub;
  var _playing = false;
  File? _file;
  var _missing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || !_playing) return;
    final player = _player;
    if (player == null) return;
    setState(() => _playing = false);
    unawaited(player.pause().catchError((Object _) {}));
  }

  @override
  void didUpdateWidget(AttachmentTile old) {
    super.didUpdateWidget(old);
    // 같은 자리에 다른 첨부가 들어오면 옛 파일·플레이어를 버린다 — 잘못된 녹음을 재생하면 안 된다.
    if (old.attachment.fileName != widget.attachment.fileName) {
      _releasePlayer();
      _playing = false;
      _file = null;
      _missing = false;
      _locate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releasePlayer();
    super.dispose();
  }

  void _releasePlayer() {
    _sub?.cancel();
    _sub = null;
    _player?.dispose();
    _player = null;
  }

  /// 파일 위치를 찾고 실제로 있는지 본다. 도중에 다른 첨부로 바뀌면 결과를 버린다.
  Future<void> _locate() async {
    final name = widget.attachment.fileName;
    final file = await ref.read(guidanceFileStoreProvider).fileOf(name);
    final exists = await file.exists();
    if (!mounted || widget.attachment.fileName != name) return;
    setState(() {
      _file = file;
      _missing = !exists;
    });
  }

  void _showMissing() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text(GuidanceStrings.attachmentMissing)),
    );
  }

  Future<void> _toggle() async {
    final file = _file;
    if (file == null || _missing) return;
    try {
      final player = _player ?? ref.read(audioPlaybackFactoryProvider)();
      if (_player == null) {
        _player = player;
        _sub = player.playing.listen((p) {
          if (mounted) setState(() => _playing = p);
        });
      }
      if (_playing) {
        await player.pause();
      } else {
        await player.play(file.path);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _playing = false);
      _showMissing();
    }
  }

  void _openImage(File file) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.file(
              file,
              errorBuilder: (_, _, _) => _brokenIcon(color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _brokenIcon({Color? color}) =>
      Icon(Icons.broken_image_outlined, color: color ?? AppColors.sub);

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    final id = a.id ?? -1;
    final file = _file;
    final base = a.type == AttachmentType.audio && a.durationMs != null
        ? '${a.source.label} · ${GuidanceStrings.durationLabel(a.durationMs ?? 0)}'
        : '${a.source.label} · ${GuidanceStrings.sizeLabel(a.byteSize)}';
    final subtitle = _missing
        ? '$base · ${GuidanceStrings.attachmentMissing}'
        : base;
    final openImage = file == null || _missing ? null : () => _openImage(file);
    final leading = a.type == AttachmentType.audio
        ? IconButton.filled(
            key: AttachmentTile.playKey(id),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
            ),
            onPressed: file == null || _missing ? null : _toggle,
            icon: Icon(
              _playing ? Icons.pause : Icons.play_arrow,
              semanticLabel: _playing ? GuidanceStrings.pause : GuidanceStrings.play,
            ),
          )
        : ButtonSemantics(label: GuidanceStrings.openImage, onTap: openImage, child: InkWell(
            key: AttachmentTile.imageKey(id),
            onTap: openImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: file == null || _missing
                    ? ColoredBox(
                        color: AppColors.surfaceVariant,
                        child: _missing ? _brokenIcon() : null,
                      )
                    : Image.file(
                        file,
                        fit: BoxFit.cover,
                        cacheWidth: 144,
                        errorBuilder: (_, _, _) => _brokenIcon(),
                      ),
              ),
            ),
          ));
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                leading,
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.originalName ?? a.type.label,
                        style: AppTextStyles.bodyM,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: AttachmentTile.infoKey(id),
                  icon: const Icon(
                    Icons.info_outline,
                    semanticLabel: GuidanceStrings.attachmentInfo,
                  ),
                  onPressed: () => showAttachmentInfo(context, a, now: widget.now),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    key: AttachmentTile.removeKey(id),
                    icon: const Icon(
                      Icons.close,
                      semanticLabel: GuidanceStrings.removeAttachment,
                    ),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            if (widget.onTranscribe != null && file != null && !_missing) ...[
              const SizedBox(height: AppSizes.spacing4),
              TextButton.icon(
                key: AttachmentTile.transcribeKey(id),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: AppColors.surfaceVariant,
                  foregroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                ),
                onPressed: widget.onTranscribe,
                icon: const Icon(Icons.notes, size: 18),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(GuidanceStrings.transcribe),
                    const SizedBox(width: AppSizes.spacing8),
                    Text(
                      GuidanceStrings.transcribeTag,
                      style: AppTextStyles.bodyS.copyWith(fontSize: 12, color: AppColors.sub),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
