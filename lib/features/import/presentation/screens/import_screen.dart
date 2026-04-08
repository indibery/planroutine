import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/import_providers.dart';
import '../widgets/import_summary_card.dart';
import '../widgets/imported_schedule_tile.dart';

/// CSV 가져오기 화면
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(importStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.importTitle)),
      body: switch (importState) {
        ImportInitial() => _buildInitialView(context, ref),
        ImportLoading() => _buildLoadingView(context),
        ImportSuccess(:final schedules, :final categorySummary, :final sourceYear) =>
          _buildSuccessView(context, ref, schedules, categorySummary, sourceYear),
        ImportError(:final message) => _buildErrorView(context, ref, message),
      },
    );
  }

  /// 초기 화면: 파일 선택 안내
  Widget _buildInitialView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.upload_file,
              size: 80,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: AppSizes.spacing24),
            Text(
              AppStrings.importDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSizes.spacing32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(importStateProvider.notifier).pickAndImportCsv();
                },
                icon: const Icon(Icons.file_open),
                label: const Text(AppStrings.importSelectFile),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 로딩 화면
  Widget _buildLoadingView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSizes.spacing16),
          Text(
            AppStrings.importParsing,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  /// 성공 화면: 요약 + 일정 목록
  Widget _buildSuccessView(
    BuildContext context,
    WidgetRef ref,
    List schedules,
    Map<String, int> categorySummary,
    int sourceYear,
  ) {
    return Column(
      children: [
        // 요약 카드
        ImportSummaryCard(
          totalCount: schedules.length,
          categorySummary: categorySummary,
          sourceYear: sourceYear,
        ),
        // 추가 가져오기 / 초기화 버튼
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(importStateProvider.notifier).reset();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text(AppStrings.retry),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacing8),
        // 일정 목록
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing8,
              vertical: AppSizes.spacing4,
            ),
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              return ImportedScheduleTile(schedule: schedules[index]);
            },
          ),
        ),
      ],
    );
  }

  /// 에러 화면
  Widget _buildErrorView(BuildContext context, WidgetRef ref, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSizes.spacing24),
            Text(
              AppStrings.importFailed,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSizes.spacing8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSizes.spacing32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(importStateProvider.notifier).pickAndImportCsv();
                },
                icon: const Icon(Icons.refresh),
                label: const Text(AppStrings.retry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
