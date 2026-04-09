import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../domain/imported_schedule.dart';
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
      appBar: AppBar(
        title: const Text(AppStrings.importTitle),
        actions: [
          // 성공 상태일 때만 초기화 버튼 표시
          if (importState is ImportSuccess)
            IconButton(
              onPressed: () {
                _cancelSelectMode(ref);
                ref.read(importStateProvider.notifier).reset();
              },
              icon: const Icon(Icons.refresh),
              tooltip: AppStrings.retry,
            ),
        ],
      ),
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

  /// 성공 화면: 요약 + 등록 버튼 + 일정 목록
  Widget _buildSuccessView(
    BuildContext context,
    WidgetRef ref,
    List<ImportedSchedule> schedules,
    Map<String, int> categorySummary,
    int sourceYear,
  ) {
    final isSelectMode = ref.watch(importSelectModeProvider);
    final selectedIds = ref.watch(selectedImportIdsProvider);

    return Column(
      children: [
        // 요약 카드
        ImportSummaryCard(
          totalCount: schedules.length,
          categorySummary: categorySummary,
          sourceYear: sourceYear,
        ),
        // 액션 버튼 영역
        if (!isSelectMode)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing16,
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
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleSelectMode(ref),
                    icon: const Icon(Icons.checklist),
                    label: const Text(AppStrings.importRegisterSelected),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing16,
            ),
            child: Row(
              children: [
                Text(
                  '${selectedIds.length}${AppStrings.importSelected}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _cancelSelectMode(ref),
                  child: const Text(AppStrings.cancel),
                ),
                const SizedBox(width: AppSizes.spacing8),
                ElevatedButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => _registerSelected(context, ref, schedules),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(AppStrings.importRegisterSelected),
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
              final schedule = schedules[index];
              if (isSelectMode) {
                final isSelected = selectedIds.contains(schedule.id);
                return GestureDetector(
                  onTap: () => _toggleSelection(ref, schedule.id),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(ref, schedule.id),
                        activeColor: AppColors.primary,
                      ),
                      Expanded(
                        child: ImportedScheduleTile(schedule: schedule),
                      ),
                    ],
                  ),
                );
              }
              return ImportedScheduleTile(schedule: schedule);
            },
          ),
        ),
      ],
    );
  }

  /// 전체 등록
  Future<void> _registerAll(
    BuildContext context,
    WidgetRef ref,
    List<ImportedSchedule> schedules,
  ) async {
    final count = await ref
        .read(importStateProvider.notifier)
        .registerAllAsSchedules(schedules);
    ref.invalidate(schedulesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count${AppStrings.importRegisterCount}')),
      );
    }
  }

  /// 선택 모드 진입
  void _toggleSelectMode(WidgetRef ref) {
    ref.read(importSelectModeProvider.notifier).state = true;
    ref.read(selectedImportIdsProvider.notifier).state = {};
  }

  /// 선택 모드 해제
  void _cancelSelectMode(WidgetRef ref) {
    ref.read(importSelectModeProvider.notifier).state = false;
    ref.read(selectedImportIdsProvider.notifier).state = {};
  }

  /// 체크박스 토글
  void _toggleSelection(WidgetRef ref, int? id) {
    if (id == null) return;
    final notifier = ref.read(selectedImportIdsProvider.notifier);
    final current = notifier.state;
    if (current.contains(id)) {
      notifier.state = {...current}..remove(id);
    } else {
      notifier.state = {...current, id};
    }
  }

  /// 선택 등록
  Future<void> _registerSelected(
    BuildContext context,
    WidgetRef ref,
    List<ImportedSchedule> schedules,
  ) async {
    final selectedIds = ref.read(selectedImportIdsProvider);
    final selected =
        schedules.where((s) => selectedIds.contains(s.id)).toList();
    final count = await ref
        .read(importStateProvider.notifier)
        .registerAllAsSchedules(selected);
    ref.invalidate(schedulesProvider);
    _cancelSelectMode(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count${AppStrings.importRegisterCount}')),
      );
    }
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
