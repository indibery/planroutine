import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../domain/imported_schedule.dart';
import '../providers/import_providers.dart';
import '../widgets/import_summary_card.dart';

/// 작년 일정 가져오기 전용 풀스크린.
///
/// 상단에 1-2-3 스테퍼가 항상 노출되어 어느 단계인지 한눈에 보이고,
/// 그 아래 state별 본문이 바뀐다.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(importStateProvider);
    final activeStep = _stepFor(importState);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          SettingsStrings.importSection,
          style: AppTextStyles.heading,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.spacing16,
              AppSizes.pagePadding,
              AppSizes.spacing8,
            ),
            child: ImportSteps(activeStep: activeStep),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: switch (importState) {
                ImportInitial() => _buildInitialView(context, ref),
                ImportLoading() => _buildLoadingView(context),
                ImportSuccess(
                  :final schedules,
                  :final categorySummary,
                  :final sourceYear
                ) =>
                  _buildSuccessView(
                    context,
                    ref,
                    schedules,
                    categorySummary,
                    sourceYear,
                  ),
                ImportRegistered(
                  :final created,
                  :final skipped,
                  :final sourceYear,
                ) =>
                  _buildRegisteredView(
                    context,
                    ref,
                    created,
                    skipped,
                    sourceYear,
                  ),
                ImportError(:final message) =>
                  _buildErrorView(context, ref, message),
              },
            ),
          ),
        ],
      ),
    );
  }

  int _stepFor(ImportState state) => switch (state) {
        ImportInitial() || ImportError() => 0,
        ImportLoading() || ImportSuccess() => 1,
        ImportRegistered() => 2,
      };

  Widget _buildInitialView(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(AppSizes.radius14),
              border: Border.all(color: AppColors.lineStrong, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.upload_file,
                  color: AppColors.gold,
                  size: 32,
                ),
                const SizedBox(height: AppSizes.spacing8),
                Text(
                  ImportStrings.description,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: AppSizes.spacing16),
                GoldGradientButton(
                  label: ImportStrings.selectFile,
                  icon: Icons.file_open,
                  onPressed: () {
                    ref
                        .read(importStateProvider.notifier)
                        .pickAndImportCsv();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.spacing32),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppColors.gold),
          SizedBox(height: AppSizes.spacing12),
          Text(
            ImportStrings.parsing,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: AppColors.sub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    WidgetRef ref,
    List<ImportedSchedule> schedules,
    Map<String, int> categorySummary,
    int sourceYear,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImportSummaryCard(
          totalCount: schedules.length,
          categorySummary: categorySummary,
          sourceYear: sourceYear,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16,
            vertical: AppSizes.spacing8,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: GoldGradientButton(
                  label: ImportStrings.registerAll,
                  icon: Icons.playlist_add_check,
                  onPressed: () =>
                      _confirmRegister(context, ref, schedules, sourceYear),
                ),
              ),
              const SizedBox(width: AppSizes.spacing8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(importStateProvider.notifier).reset(),
                  child: const Text(AppStrings.cancel),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisteredView(
    BuildContext context,
    WidgetRef ref,
    int created,
    int skipped,
    int sourceYear,
  ) {
    final skippedMessage = skipped > 0 ? ' (중복 $skipped건 제외)' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(AppSizes.radius14),
          border: Border.all(
            color: AppColors.inkGreen.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.inkGreen,
                ),
                const SizedBox(width: AppSizes.spacing8),
                Text(
                  '$sourceYear${AppStrings.compareYearFormat} 일정 $created${ImportStrings.registerCount}',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            if (skippedMessage.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spacing4),
              Text(
                skippedMessage.trim(),
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  color: AppColors.sub,
                ),
              ),
            ],
            const SizedBox(height: AppSizes.spacing12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(importStateProvider.notifier).reset(),
                icon: const Icon(Icons.file_open, size: 16),
                label: const Text(ImportStrings.selectFileAgain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    WidgetRef ref,
    String message,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.inkRed),
              const SizedBox(width: AppSizes.spacing8),
              const Text(
                ImportStrings.failed,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          GoldGradientButton(
            label: AppStrings.retry,
            icon: Icons.refresh,
            onPressed: () =>
                ref.read(importStateProvider.notifier).pickAndImportCsv(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRegister(
    BuildContext context,
    WidgetRef ref,
    List<ImportedSchedule> schedules,
    int sourceYear,
  ) async {
    await ref
        .read(importStateProvider.notifier)
        .registerAllAsSchedules(schedules, sourceYear);
    ref.invalidate(schedulesProvider);
  }
}

/// 가져오기 3단계 인디케이터 — ① 파일 선택 · ② 분석 · ③ 등록.
class ImportSteps extends StatelessWidget {
  const ImportSteps({super.key, required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepDot(index: 0, active: activeStep >= 0),
        _StepLine(active: activeStep >= 1),
        _StepDot(index: 1, active: activeStep >= 1),
        _StepLine(active: activeStep >= 2),
        _StepDot(index: 2, active: activeStep >= 2),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.active});

  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.gold : Colors.transparent,
        border: Border.all(
          color: active ? AppColors.gold : AppColors.faint,
          width: 1,
        ),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.navy : AppColors.faint,
        ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: AppSizes.spacing4),
        color: active ? AppColors.gold : AppColors.faint,
      ),
    );
  }
}
