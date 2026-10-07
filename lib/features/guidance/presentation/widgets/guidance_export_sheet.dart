import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/sheet_title.dart';
import '../../data/guidance_exporter.dart';
import '../../domain/guidance_export.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../lock/system_sheet_guard.dart';
import '../providers/guidance_providers.dart';

/// 보냈으면(또는 결과를 알 수 없으면) true, 공유 창에서 취소했으면 false.
typedef ShareExport = Future<bool> Function(ExportOutput out, Rect? origin);

/// 저장했으면 true, 저장 창에서 취소했으면 false.
typedef SaveExport = Future<bool> Function(ExportOutput out);

/// 여러 파일 공유(녹음만). 보냈으면(또는 결과를 알 수 없으면) true.
typedef ShareFiles = Future<bool> Function(List<String> paths, Rect? origin);

Future<bool> _shareFilesViaSheet(List<String> paths, Rect? origin) async {
  final result = await Share.shareXFiles(
    [for (final p in paths) XFile(p)],
    sharePositionOrigin: origin,
  );
  return result.status != ShareResultStatus.dismissed;
}

/// 임시 폴더에 쓰고 공유시트를 연 뒤, 닫히면(결과·실패와 무관) 지운다 — 기록 내용이 담긴 파일이다.
/// ⚠️ 안드로이드의 share_plus는 넘긴 파일을 자기 캐시(`cache/share_plus/`)에 한 번 더 복사하고 그 사본은
/// 다음 공유 때까지 남는다 — 앱 샌드박스 안이라 노출 범위는 DB와 같다.
@visibleForTesting
Future<bool> shareViaSheet(
  ExportOutput out,
  Rect? origin, {
  Future<Directory> Function()? tempDir,
  Future<bool> Function(String path, Rect? origin)? share,
}) async {
  final dir = Directory(p.join((await (tempDir ?? getTemporaryDirectory)()).path, 'guidance_export'));
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, out.fileName));
  await file.writeAsBytes(out.bytes, flush: true);
  try {
    return await (share ?? _shareFile)(file.path, origin);
  } finally {
    try {
      await file.delete();
    } catch (_) {}
  }
}

/// 취소(`dismissed`)만 false다. 결과를 알 수 없는 경우(`unavailable`)는 보낸 것으로 친다 —
/// 시트가 남아 있으면 사용자가 닫는 법을 찾아 헤맨다(실기기 피드백 2026-10-05).
Future<bool> _shareFile(String path, Rect? origin) async {
  final result = await Share.shareXFiles([XFile(path)], sharePositionOrigin: origin);
  return result.status != ShareResultStatus.dismissed;
}

/// 안드로이드 저장 위치 선택 창(SAF). 공유시트에는 "파일로 저장"하는 공통 항목이 없다.
Future<bool> _saveViaPicker(ExportOutput out) async {
  final path = await SystemSheetGuard.run(
    () =>
        FilePicker.platform.saveFile(fileName: out.fileName, bytes: out.bytes),
  );
  return path != null;
}

/// 보내기를 마치면 시트가 닫히고 결과를 이 화면의 스낵바로 알린다 — 시트가 열린 채면 스낵바가 가려지고,
/// 닫는 법을 찾아 헤맨다(실기기 피드백 2026-10-05). 문구는 상수뿐이라 기록 내용이 잠금 덮개 밖에 남지 않는다.
Future<void> showGuidanceExportSheet(
  BuildContext context,
  WidgetRef ref, {
  required GuidanceRecord record,
  required List<GuidanceAttachment> attachments,
  @visibleForTesting bool? isAndroid,
  @visibleForTesting ShareExport? share,
  @visibleForTesting SaveExport? save,
  @visibleForTesting ShareFiles? shareFiles,
  @visibleForTesting Future<Directory> Function()? tempDir,
}) async {
  final available = await ref
      .read(guidanceExporterProvider)
      .availableIds(attachments);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final message = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => GuidanceExportSheet(
      record: record,
      attachments: attachments,
      availableIds: available,
      isAndroid: isAndroid,
      share: share,
      save: save,
      shareFiles: shareFiles,
      tempDir: tempDir,
    ),
  );
  if (message != null) messenger?.showSnackBar(SnackBar(content: Text(message)));
}

/// 위에서 무엇을(ZIP / PDF만) 고르고, 아래 버튼으로 어떻게(공유 / 기기에 저장) 보낼지 고른다.
class GuidanceExportSheet extends ConsumerStatefulWidget {
  const GuidanceExportSheet({
    super.key,
    required this.record,
    required this.attachments,
    required this.availableIds,
    this.isAndroid,
    this.share,
    this.save,
    this.shareFiles,
    this.tempDir,
  });

  final GuidanceRecord record;
  final List<GuidanceAttachment> attachments;

  /// 디스크에 파일이 있는 첨부. 없으면 그 줄은 꺼진다(안드로이드 백업 복원은 첨부 폴더를 뺀다).
  final Set<int> availableIds;

  /// 기본은 `Platform.isAndroid` — `defaultTargetPlatform`은 테스트에서 늘 android다.
  final bool? isAndroid;
  final ShareExport? share;
  final SaveExport? save;
  final ShareFiles? shareFiles;
  final Future<Directory> Function()? tempDir;

  static const bundleKey = Key('guidance_export_bundle');
  static const pdfOnlyKey = Key('guidance_export_pdf_only');
  static const audioOnlyKey = Key('guidance_export_audio_only');
  static const saveOneOnlyKey = Key('guidance_export_save_one_only');
  static const shareKey = Key('guidance_export_share');
  static const saveKey = Key('guidance_export_save');
  static const guideKey = Key('guidance_export_guide');
  static const handleKey = Key('guidance_export_handle');
  static Key attachmentKey(int id) => Key('guidance_export_attachment_$id');

  @override
  ConsumerState<GuidanceExportSheet> createState() =>
      _GuidanceExportSheetState();
}

class _GuidanceExportSheetState extends ConsumerState<GuidanceExportSheet> {
  late final List<GuidanceAttachment> _visible = [
    for (final a in widget.attachments)
      if (!a.isRemoved) a,
  ];
  late final Set<int> _selected = {...widget.availableIds};
  late ExportKind _kind = widget.availableIds.isEmpty
      ? ExportKind.pdfOnly
      : ExportKind.bundle;
  final _shareAnchor = GlobalKey();
  var _busy = false;

  /// 실패 안내. 열린 시트에 스낵바는 가려지므로(에뮬레이터 확인) 시트 안에 남긴다.
  String? _status;

  bool get _android => widget.isAndroid ?? Platform.isAndroid;
  bool get _audioOnly => _kind == ExportKind.audioOnly;
  bool get _hasAudio => _visible.any(
    (a) => a.type == AttachmentType.audio && widget.availableIds.contains(a.id),
  );
  int get _pickedAudio => _visible
      .where((a) => a.type == AttachmentType.audio && _selected.contains(a.id))
      .length;
  bool get _canSend =>
      !_busy &&
      switch (_kind) {
        ExportKind.pdfOnly => true,
        ExportKind.bundle => _selected.isNotEmpty,
        ExportKind.audioOnly => _pickedAudio > 0,
      };

  /// 안드로이드 저장 창(SAF)은 한 번에 파일 하나 — 녹음만은 1개일 때만.
  bool get _canSave => _canSend && (!_audioOnly || _pickedAudio == 1);

  /// 아이패드는 공유 창의 기준 위치가 없으면 예외를 던진다(`export_list_tile.dart`와 같은 이유).
  Rect? _origin() {
    final box = _shareAnchor.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// [send]가 문구를 돌려주면 보내기가 끝난 것이다 — 시트를 닫고 그 문구를 화면에 넘긴다.
  /// null이면(취소) 시트를 그대로 둔다. 실패는 시트 안 상태 줄에 남긴다(시트가 열려 있어 스낵바는 가려진다).
  Future<void> _run(Future<String?> Function(ExportOutput out) send) async {
    if (!_canSend) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    String? done;
    try {
      final out = await ref
          .read(guidanceExporterProvider)
          .build(record: widget.record, attachments: _visible, selectedIds: _selected, kind: _kind);
      done = await send(out);
    } catch (_) {
      // 기록 내용(제목·이름)은 넣지 않는다.
      if (mounted) setState(() => _status = GuidanceStrings.exportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (done != null && mounted) await Navigator.of(context).maybePop(done);
  }

  Future<void> _share() => _audioOnly
      ? _runAudio()
      : _run(
          (out) async => await (widget.share ?? shareViaSheet)(out, _origin()) ? GuidanceStrings.exportShared : null,
        );

  Future<void> _save() => _audioOnly
      ? _runAudio(save: true)
      : _run(
          (out) async => await (widget.save ?? _saveViaPicker)(out) ? GuidanceStrings.exportSaved : null,
        );

  /// 녹음만 — 원본을 임시 폴더로 복사해 보내고, 결과와 무관하게 사본을 지운다(기록이 담긴 파일이다).
  Future<void> _runAudio({bool save = false}) async {
    if (!(save ? _canSave : _canSend)) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    String? done;
    var copies = const <File>[];
    try {
      final base = await (widget.tempDir ?? getTemporaryDirectory)();
      copies = await ref
          .read(guidanceExporterProvider)
          .copyAudioForShare(
            record: widget.record,
            attachments: _visible,
            // 고른 녹음만 — 사진은 고른 상태로 남아 있어도 보내지 않는다.
            selectedIds: {
              for (final a in _visible)
                if (a.type == AttachmentType.audio && _selected.contains(a.id)) ?a.id,
            },
            dir: Directory(p.join(base.path, 'guidance_export')),
          );
      if (save) {
        // SAF 저장 창은 바이트를 요구한다 — 1개일 때만 여기 온다.
        final f = copies.single;
        final ok = await (widget.save ?? _saveViaPicker)(
          ExportOutput(fileName: p.basename(f.path), bytes: await f.readAsBytes()),
        );
        done = ok ? GuidanceStrings.exportSaved : null;
      } else {
        final ok = await (widget.shareFiles ?? _shareFilesViaSheet)(
          [for (final f in copies) f.path],
          _origin(),
        );
        done = ok ? GuidanceStrings.exportShared : null;
      }
    } catch (_) {
      // 기록 내용(제목·이름)은 넣지 않는다.
      if (mounted) setState(() => _status = GuidanceStrings.exportFailed);
    } finally {
      for (final f in copies) {
        try {
          await f.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
    if (done != null && mounted) await Navigator.of(context).maybePop(done);
  }

  @override
  Widget build(BuildContext context) {
    bool picked(GuidanceAttachment a, AttachmentType t) =>
        a.type == t && _selected.contains(a.id);
    final audio = _visible.where((a) => picked(a, AttachmentType.audio)).length;
    final image = _visible.where((a) => picked(a, AttachmentType.image)).length;
    final now = DateTime.now();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSizes.spacing20, AppSizes.spacing12, AppSizes.spacing20, AppSizes.spacing20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 끌어 내려 닫을 수 있다는 표시 — 도장 모양 시트와 같은 손잡이.
            Center(
              child: Container(
                key: GuidanceExportSheet.handleKey,
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.faint,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            const SheetTitle(GuidanceStrings.export),
            const SizedBox(height: AppSizes.spacing12),
            RadioGroup<ExportKind>(
              groupValue: _kind,
              onChanged: (v) => setState(() => _kind = v ?? _kind),
              child: Column(
                children: [
                  if (_visible.isNotEmpty)
                    RadioListTile<ExportKind>(
                      key: GuidanceExportSheet.bundleKey,
                      value: ExportKind.bundle,
                      enabled: widget.availableIds.isNotEmpty,
                      title: const Text(GuidanceStrings.exportBundle),
                      subtitle: Text(
                        GuidanceStrings.exportBundleSubtitle(audio, image),
                      ),
                    ),
                  if (_hasAudio)
                    const RadioListTile<ExportKind>(
                      key: GuidanceExportSheet.audioOnlyKey,
                      value: ExportKind.audioOnly,
                      title: Text(GuidanceStrings.exportAudioOnly),
                      subtitle: Text(GuidanceStrings.exportAudioOnlySubtitle),
                    ),
                  const RadioListTile<ExportKind>(
                    key: GuidanceExportSheet.pdfOnlyKey,
                    value: ExportKind.pdfOnly,
                    title: Text(GuidanceStrings.exportPdfOnly),
                    subtitle: Text(GuidanceStrings.exportPdfOnlySubtitle),
                  ),
                ],
              ),
            ),
            if (_visible.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spacing8),
              Text(
                GuidanceStrings.labelAttachments,
                style: AppTextStyles.fieldLabel,
              ),
              for (final a in _visible) _attachmentRow(a, now),
            ],
            const SizedBox(height: AppSizes.spacing12),
            _PcGuide(isAndroid: _android),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              GuidanceStrings.exportNotice,
              style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
            ),
            const SizedBox(height: AppSizes.spacing12),
            if (_status case final status?) ...[
              Text(
                status,
                style: AppTextStyles.bodyS.copyWith(
                  color: status == GuidanceStrings.exportFailed ? AppColors.error : AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
            ],
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: AppSizes.spacing8),
            Row(
              children: [
                if (_android) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: GuidanceExportSheet.saveKey,
                      onPressed: _canSave ? _save : null,
                      child: const Text(GuidanceStrings.exportSaveToDevice),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacing8),
                ],
                Expanded(
                  child: FilledButton(
                    key: GuidanceExportSheet.shareKey,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.goldFill,
                      foregroundColor: AppColors.onGold,
                    ),
                    onPressed: _canSend ? _share : null,
                    child: Text(GuidanceStrings.exportShare, key: _shareAnchor),
                  ),
                ),
              ],
            ),
            if (_android && _audioOnly && _pickedAudio > 1)
              Padding(
                key: GuidanceExportSheet.saveOneOnlyKey,
                padding: const EdgeInsets.only(top: AppSizes.spacing4),
                child: Text(
                  GuidanceStrings.exportAudioSaveOneOnly,
                  style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentRow(GuidanceAttachment a, DateTime now) {
    final id = a.id;
    final present = id != null && widget.availableIds.contains(id);
    // 녹음만 보낼 때 사진은 고를 수 없다 — 고른 상태는 남겨 두어 다른 방식으로 돌아가면 그대로다.
    final excluded = _audioOnly && a.type == AttachmentType.image;
    final ms = a.durationMs;
    final size = ms == null
        ? GuidanceStrings.sizeLabel(a.byteSize)
        : GuidanceStrings.durationLabel(ms);
    return CheckboxListTile(
      key: GuidanceExportSheet.attachmentKey(id ?? -1),
      contentPadding: EdgeInsets.zero,
      value: !excluded && present && _selected.contains(id),
      onChanged: present && !excluded
          ? (v) => setState(
              () => (v ?? false) ? _selected.add(id) : _selected.remove(id),
            )
          : null,
      secondary: Icon(
        a.type == AttachmentType.audio ? Icons.mic_none : Icons.image_outlined,
      ),
      title: Text('${a.type.label} · $size'),
      subtitle: Text(
        excluded
            ? GuidanceStrings.exportAudioOnlyExcluded
            : present
            ? formatStamp(a.capturedAt ?? a.attachedAt, now: now)
            : GuidanceStrings.attachmentMissing,
      ),
    );
  }
}

/// PC로 옮기는 방법 — 기기마다 자기 안내만. 배경·테두리는 Material이 진다
/// (ListTile 위에 색칠된 컨테이너를 끼우면 잉크가 가려진다 — 에듀파인 안내와 같은 조립).
class _PcGuide extends StatelessWidget {
  const _PcGuide({required this.isAndroid});

  final bool isAndroid;

  @override
  Widget build(BuildContext context) {
    final steps = isAndroid
        ? GuidanceStrings.exportPcGuideAndroid
        : GuidanceStrings.exportPcGuideIos;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        child: Material(
          color: AppColors.glass,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.line, width: 0.6),
            borderRadius: BorderRadius.circular(AppSizes.radius14),
          ),
          child: ExpansionTile(
            key: GuidanceExportSheet.guideKey,
            leading: Icon(
              Icons.computer_outlined,
              color: AppColors.gold,
              size: 20,
            ),
            title: const Text(GuidanceStrings.exportPcGuideTitle),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSizes.cardPadding,
              0,
              AppSizes.cardPadding,
              AppSizes.cardPadding,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, s) in steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spacing4),
                  child: Text('${i + 1}. $s', style: AppTextStyles.bodyS),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
