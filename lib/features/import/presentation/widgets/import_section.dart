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
                  onPressed: () => _registerAll(context, ref, schedules),
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text(AppStrings.importRegisterAll),
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

  String _buildResultMessage(({int created, int skipped}) result) {
    if (result.created == 0 && result.skipped > 0) {
      return '이미 전체 등록됨 (${result.skipped}건 중복)';
    } else if (result.skipped > 0) {
      return '${result.created}${AppStrings.importRegisterCount} (중복 ${result.skipped}건 제외)';
    }
    return '${result.created}${AppStrings.importRegisterCount}';
  }

  Future<void> _registerAll(
    BuildContext context,
    WidgetRef ref,
    List<ImportedSchedule> schedules,
  ) async {
    final result = await ref
        .read(importStateProvider.notifier)
        .registerAllAsSchedules(schedules);
    ref.invalidate(schedulesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(_buildResultMessage(result))),
        );
    }
  }
}
