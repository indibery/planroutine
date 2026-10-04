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

typedef ShareExport = Future<void> Function(ExportOutput out, Rect? origin);

/// 저장했으면 true, 저장 창에서 취소했으면 false.
typedef SaveExport = Future<bool> Function(ExportOutput out);

/// 임시 폴더에 쓰고 공유시트를 연 뒤, 닫히면(결과·실패와 무관) 지운다 — 기록 내용이 담긴 파일이다.
/// ⚠️ 안드로이드의 share_plus는 넘긴 파일을 자기 캐시(`cache/share_plus/`)에 한 번 더 복사하고 그 사본은
/// 다음 공유 때까지 남는다 — 앱 샌드박스 안이라 노출 범위는 DB와 같다.
@visibleForTesting
Future<void> shareViaSheet(
  ExportOutput out,
  Rect? origin, {
  Future<Directory> Function()? tempDir,
  Future<void> Function(String path, Rect? origin)? share,
}) async {
  final dir = Directory(p.join((await (tempDir ?? getTemporaryDirectory)()).path, 'guidance_export'));
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, out.fileName));
  await file.writeAsBytes(out.bytes, flush: true);
  try {
    await (share ?? _shareFile)(file.path, origin);
  } finally {
    try {
      await file.delete();
    } catch (_) {}
  }
}

Future<void> _shareFile(String path, Rect? origin) async {
  await Share.shareXFiles([XFile(path)], sharePositionOrigin: origin);
}

/// 안드로이드 저장 위치 선택 창(SAF). 공유시트에는 "파일로 저장"하는 공통 항목이 없다.
Future<bool> _saveViaPicker(ExportOutput out) async {
  final path = await SystemSheetGuard.run(
    () =>
        FilePicker.platform.saveFile(fileName: out.fileName, bytes: out.bytes),
  );
  return path != null;
}

Future<void> showGuidanceExportSheet(
  BuildContext context,
  WidgetRef ref, {
  required GuidanceRecord record,
  required List<GuidanceAttachment> attachments,
}) async {
  final available = await ref
      .read(guidanceExporterProvider)
      .availableIds(attachments);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => GuidanceExportSheet(
      record: record,
      attachments: attachments,
      availableIds: available,
    ),
  );
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
  });

  final GuidanceRecord record;
  final List<GuidanceAttachment> attachments;

  /// 디스크에 파일이 있는 첨부. 없으면 그 줄은 꺼진다(안드로이드 백업 복원은 첨부 폴더를 뺀다).
  final Set<int> availableIds;

  /// 기본은 `Platform.isAndroid` — `defaultTargetPlatform`은 테스트에서 늘 android다.
  final bool? isAndroid;
  final ShareExport? share;
  final SaveExport? save;

  static const bundleKey = Key('guidance_export_bundle');
  static const pdfOnlyKey = Key('guidance_export_pdf_only');
  static const shareKey = Key('guidance_export_share');
  static const saveKey = Key('guidance_export_save');
  static const guideKey = Key('guidance_export_guide');
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

  /// 결과 안내. 스낵바로 띄우면 열린 시트에 가려 보이지 않는다(에뮬레이터 확인) — 시트 안에 남긴다.
  String? _status;

  bool get _android => widget.isAndroid ?? Platform.isAndroid;
  bool get _canSend =>
      !_busy && (_kind == ExportKind.pdfOnly || _selected.isNotEmpty);

  /// 아이패드는 공유 창의 기준 위치가 없으면 예외를 던진다(`export_list_tile.dart`와 같은 이유).
  Rect? _origin() {
    final box = _shareAnchor.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _run(Future<String?> Function(ExportOutput out) send) async {
    if (!_canSend) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    String? status;
    try {
      final out = await ref
          .read(guidanceExporterProvider)
          .build(record: widget.record, attachments: _visible, selectedIds: _selected, kind: _kind);
      status = await send(out);
    } catch (_) {
      // 기록 내용(제목·이름)은 넣지 않는다.
      status = GuidanceStrings.exportFailed;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = status;
        });
      }
    }
  }

  Future<void> _share() => _run((out) async {
    await (widget.share ?? shareViaSheet)(out, _origin());
    return null;
  });

  Future<void> _save() => _run(
    (out) async => await (widget.save ?? _saveViaPicker)(out) ? GuidanceStrings.exportSaved : null,
  );

  @override
  Widget build(BuildContext context) {
    bool picked(GuidanceAttachment a, AttachmentType t) =>
        a.type == t && _selected.contains(a.id);
    final audio = _visible.where((a) => picked(a, AttachmentType.audio)).length;
    final image = _visible.where((a) => picked(a, AttachmentType.image)).length;
    final now = DateTime.now();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.spacing20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                      onPressed: _canSend ? _save : null,
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
          ],
        ),
      ),
    );
  }

  Widget _attachmentRow(GuidanceAttachment a, DateTime now) {
    final id = a.id;
    final present = id != null && widget.availableIds.contains(id);
    final ms = a.durationMs;
    final size = ms == null
        ? GuidanceStrings.sizeLabel(a.byteSize)
        : GuidanceStrings.durationLabel(ms);
    return CheckboxListTile(
      key: GuidanceExportSheet.attachmentKey(id ?? -1),
      contentPadding: EdgeInsets.zero,
      value: present && _selected.contains(id),
      onChanged: present
          ? (v) => setState(
              () => (v ?? false) ? _selected.add(id) : _selected.remove(id),
            )
          : null,
      secondary: Icon(
        a.type == AttachmentType.audio ? Icons.mic_none : Icons.image_outlined,
      ),
      title: Text('${a.type.label} · $size'),
      subtitle: Text(
        present
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
