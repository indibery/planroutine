import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../domain/imported_schedule.dart';
import '../providers/import_providers.dart';
import 'import_summary_card.dart';

/// 설정 화면 등에 인라인으로 임베드되는 가져오기 섹션.
///
/// 기존 ImportScreen의 body 로직을 Scaffold 바깥에서 재사용 가능하게 한 버전.
class ImportSection extends ConsumerWidget {
  const ImportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(importStateProvider);

    return switch (importState) {
      ImportInitial() => _buildInitialView(context, ref),
      ImportLoading() => _buildLoadingView(context),
      ImportSuccess(:final schedules, :final categorySummary, :final sourceYear) =>
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
        _buildRegisteredView(context, ref, created, skipped, sourceYear),
      ImportError(:final message) => _buildErrorView(context, ref, message),
    };
  }

  /// 초기: CSV 파일 선택 버튼
  Widget _buildInitialView(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.importDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(importStateProvider.notifier).pickAndImportCsv();
              },
              icon: const Icon(Icons.file_open),
              label: const Text(AppStrings.importSelectFile),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing24),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppSizes.spacing12),
          Text(
            AppStrings.importParsing,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
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
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _confirmRegister(context, ref, schedules, sourceYear),
                  icon: const Icon(Icons.check),
                  label: const Text(AppStrings.confirm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spacing8),
              IconButton(
                tooltip: AppStrings.retry,
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    ref.read(importStateProvider.notifier).reset(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 등록 완료 상태 — 사용자가 결과를 명시적으로 확인 가능
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
        padding: const EdgeInsets.all(AppSizes.spacing16),
        decoration: BoxDecoration(
          color: AppColors.statusConfirmed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          border: Border.all(
            color: AppColors.statusConfirmed.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.statusConfirmed,
                ),
                const SizedBox(width: AppSizes.spacing8),
                Text(
                  '$sourceYear${AppStrings.compareYearFormat} 일정 $created${AppStrings.importRegisterCount}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (skippedMessage.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spacing4),
              Text(
                skippedMessage.trim(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
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
                label: const Text(AppStrings.importSelectFileAgain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, WidgetRef ref, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: AppSizes.spacing8),
              Text(
                AppStrings.importFailed,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  ref.read(importStateProvider.notifier).pickAndImportCsv(),
              icon: const Icon(Icons.refresh),
              label: const Text(AppStrings.retry),
            ),
          ),
        ],
      ),
    );
  }

  /// 확인 버튼 → 등록 수행 후 notifier가 ImportRegistered 상태로 전환,
  /// 그 상태에서 결과가 화면에 인라인 표시됨(스낵바 사용 없음).
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
