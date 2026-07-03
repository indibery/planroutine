import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_utils.dart' as du;
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../data/ai_schedule_parser.dart';
import '../../data/ai_schedule_register.dart';

/// AI 사진 변환 가져오기 — 파일 없이 클립보드만으로:
/// ① 변환 프롬프트 복사 → AI 앱(사진+프롬프트) → 응답 복사 →
/// ② 붙여넣기 → 미리보기(중복 제외 표시) → 검토 대기(pending) 등록.
class AiPhotoImportSection extends ConsumerWidget {
  const AiPhotoImportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        border: Border.all(color: AppColors.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ImportStrings.aiTitle,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSizes.spacing4),
          Text(
            ImportStrings.aiDescription,
            style: TextStyle(fontSize: 12, color: AppColors.sub),
          ),
          const SizedBox(height: AppSizes.spacing12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _copyPrompt(context),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text(ImportStrings.aiCopyPrompt),
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _pasteAndPreview(context, ref),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text(ImportStrings.aiPaste),
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            ImportStrings.aiHint,
            style: TextStyle(fontSize: 11, color: AppColors.faint),
          ),
        ],
      ),
    );
  }

  Future<void> _copyPrompt(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: buildAiPhotoPrompt(DateTime.now())),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
          const SnackBar(content: Text(ImportStrings.aiPromptCopied)));
  }

  Future<void> _pasteAndPreview(BuildContext context, WidgetRef ref) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final parsed = parseAiScheduleJson(data?.text ?? '');
    if (!context.mounted) return;
    if (parsed.items.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
            const SnackBar(content: Text(ImportStrings.aiParseEmpty)));
      return;
    }

    // 기존 활성 일정(title+date)과 대조해 미리보기에서 중복을 표시.
    final existing = await ref.read(scheduleRepositoryProvider).getSchedules();
    final existingKeys =
        existing.map((s) => '${s.title}|${s.scheduledDate}').toSet();
    final seen = <String>{};
    final fresh = <AiScheduleItem>[];
    var dupCount = 0;
    for (final item in parsed.items) {
      final key = '${item.title}|${item.date}';
      if (existingKeys.contains(key) || !seen.add(key)) {
        dupCount++;
      } else {
        fresh.add(item);
      }
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.navyMid,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSizes.radius16)),
      ),
      builder: (sheetContext) => _AiPreviewSheet(
        items: parsed.items,
        freshCount: fresh.length,
        dupCount: dupCount,
        onRegister: () async {
          final result = await registerAiSchedules(
            ref.read(scheduleRepositoryProvider),
            fresh,
          );
          ref.invalidate(schedulesProvider);
          if (!sheetContext.mounted) return;
          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(
                content: Text(ImportStrings.aiRegistered(result.created))));
        },
      ),
    );
  }
}

/// 붙여넣기 미리보기 바텀시트 — 인식/중복 건수 + 항목 목록 + 등록 확정.
class _AiPreviewSheet extends StatelessWidget {
  const _AiPreviewSheet({
    required this.items,
    required this.freshCount,
    required this.dupCount,
    required this.onRegister,
  });

  final List<AiScheduleItem> items;
  final int freshCount;
  final int dupCount;
  final Future<void> Function() onRegister;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.spacing16,
        right: AppSizes.spacing16,
        top: AppSizes.spacing16,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + AppSizes.spacing16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ImportStrings.aiPreviewTitle,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSizes.spacing4),
            Text(
              dupCount > 0
                  ? '${ImportStrings.aiPreviewCount(items.length)} · ${ImportStrings.aiPreviewDup(dupCount)}'
                  : ImportStrings.aiPreviewCount(items.length),
              style: TextStyle(fontSize: 12, color: AppColors.sub),
            ),
            const SizedBox(height: AppSizes.spacing12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSizes.spacing8),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.goldMuted,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radius4),
                          ),
                        ),
                        const SizedBox(width: AppSizes.spacing8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                du.formatDate(DateTime.parse(item.date)),
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.faint),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(AppStrings.cancel),
                  ),
                ),
                const SizedBox(width: AppSizes.spacing8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: freshCount > 0 ? onRegister : null,
                    child: Text(ImportStrings.aiRegisterButton(freshCount)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
