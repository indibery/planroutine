import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/settings_providers.dart';

/// 현재 일정 CSV로 내보내기 (iOS 공유시트).
class ExportListTile extends ConsumerStatefulWidget {
  const ExportListTile({super.key});

  @override
  ConsumerState<ExportListTile> createState() => _ExportListTileState();
}

class _ExportListTileState extends ConsumerState<ExportListTile> {
  bool _exporting = false;

  /// iOS 공유시트가 popup을 띄울 때 쓰는 앵커 Rect.
  /// ListTile의 화면상 위치를 반환. RenderBox 못 구하면 안전한 fallback 제공.
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.of(context).size;
    return Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1);
  }

  Future<void> _onExport() async {
    // iOS/iPad에서 Share popup 앵커로 쓸 ListTile의 화면상 위치를 미리 구함
    // (sharePositionOrigin 미지정 시 iOS에서 PlatformException 발생)
    final origin = _shareOrigin();

    setState(() => _exporting = true);
    try {
      final exporter = ref.read(scheduleCsvExporterProvider);
      final result = await exporter.exportActiveSchedules();
      if (result.count == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.settingsExportEmpty)),
          );
        }
        return;
      }
      await Share.shareXFiles(
        [XFile(result.filePath)],
        subject: AppStrings.settingsExportShareSubject,
        text: '${result.count}${AppStrings.settingsExportShareCountSuffix}',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.settingsExportFailed}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.ios_share, color: AppColors.primary),
      title: const Text(AppStrings.settingsExportTitle),
      trailing: _exporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _exporting ? null : _onExport,
    );
  }
}
