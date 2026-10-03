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

/// 첨부 한 줄. 녹음은 재생/멈춤, 사진은 썸네일(누르면 전체 화면). ⓘ로 해시·원래 이름을 본다.
class AttachmentTile extends ConsumerStatefulWidget {
  const AttachmentTile({super.key, required this.attachment, required this.now, this.onRemove});

  final GuidanceAttachment attachment;
  final DateTime now;
  final VoidCallback? onRemove;

  static Key playKey(int id) => Key('att_play_$id');
  static Key infoKey(int id) => Key('att_info_$id');
  static Key removeKey(int id) => Key('att_remove_$id');
  static Key imageKey(int id) => Key('att_image_$id');

  @override
  ConsumerState<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends ConsumerState<AttachmentTile> {
  AudioPlayback? _player;
  StreamSubscription<bool>? _sub;
  var _playing = false;
  File? _file;

  @override
  void initState() {
    super.initState();
    ref.read(guidanceFileStoreProvider).fileOf(widget.attachment.fileName).then((f) {
      if (mounted) setState(() => _file = f);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final file = _file;
    if (file == null) return;
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
  }

  void _openImage(File file) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(child: InteractiveViewer(child: Image.file(file))),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    final id = a.id ?? -1;
    final file = _file;
    final subtitle = a.type == AttachmentType.audio && a.durationMs != null
        ? '${a.source.label} · ${GuidanceStrings.durationLabel(a.durationMs ?? 0)}'
        : '${a.source.label} · ${GuidanceStrings.sizeLabel(a.byteSize)}';
    final leading = a.type == AttachmentType.audio
        ? IconButton.filled(
            key: AttachmentTile.playKey(id),
            tooltip: _playing ? GuidanceStrings.pause : GuidanceStrings.play,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
            ),
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          )
        : InkWell(
            key: AttachmentTile.imageKey(id),
            onTap: file == null ? null : () => _openImage(file),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: file == null
                    ? ColoredBox(color: AppColors.surfaceVariant)
                    : Image.file(file, fit: BoxFit.cover, cacheWidth: 144),
              ),
            ),
          );
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing8),
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.originalName ?? a.type.label, style: AppTextStyles.bodyM, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
                ],
              ),
            ),
            IconButton(
              key: AttachmentTile.infoKey(id),
              tooltip: GuidanceStrings.attachmentInfo,
              icon: const Icon(Icons.info_outline),
              onPressed: () => showAttachmentInfo(context, a, now: widget.now),
            ),
            if (widget.onRemove != null)
              IconButton(
                key: AttachmentTile.removeKey(id),
                tooltip: GuidanceStrings.removeAttachment,
                icon: const Icon(Icons.close),
                onPressed: widget.onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
