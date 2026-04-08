import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../domain/compare_item.dart';
import '../providers/compare_providers.dart';
import '../widgets/compare_pair_card.dart';

/// 작년/올해 일정 비교 화면
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compareAsync = ref.watch(compareItemsProvider);
    final years = ref.watch(selectedYearsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.compareTitle),
      ),
      body: Column(
        children: [
          _buildYearSelector(context, ref, years),
          const Divider(height: 1),
          Expanded(
            child: compareAsync.when(
              data: (items) => items.isEmpty
                  ? _buildEmptyState()
                  : _buildCompareList(context, ref, items),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.error,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: AppSizes.spacing8),
                    TextButton(
                      onPressed: () => ref.invalidate(compareItemsProvider),
                      child: const Text(AppStrings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector(
    BuildContext context,
    WidgetRef ref,
    ({int lastYear, int thisYear}) years,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing12,
      ),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: _YearDropdown(
              label: AppStrings.compareLastYear,
              value: years.lastYear,
              onChanged: (year) {
                ref.read(selectedYearsProvider.notifier).state = (
                  lastYear: year,
                  thisYear: years.thisYear,
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.spacing12),
            child: Icon(
              Icons.compare_arrows,
              color: AppColors.textHint,
            ),
          ),
          Expanded(
            child: _YearDropdown(
              label: AppStrings.compareThisYear,
              value: years.thisYear,
              onChanged: (year) {
                ref.read(selectedYearsProvider.notifier).state = (
                  lastYear: years.lastYear,
                  thisYear: year,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.compare_arrows,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: AppSizes.spacing16),
          const Text(
            AppStrings.compareNoData,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareList(
    BuildContext context,
    WidgetRef ref,
    List<CompareItem> items,
  ) {
    // 월별 그룹핑
    final grouped = <int, List<CompareItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.sortMonth, () => []).add(item);
    }

    // 각 월 그룹 내 날짜 오름차순 정렬
    for (final entries in grouped.values) {
      entries.sort((a, b) {
        final dayA = _extractDay(a);
        final dayB = _extractDay(b);
        return dayA.compareTo(dayB);
      });
    }

    final sortedMonths = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing48),
      itemCount: sortedMonths.length,
      itemBuilder: (context, index) {
        final month = sortedMonths[index];
        final monthItems = grouped[month] ?? [];
        return _buildMonthGroup(context, ref, month, monthItems);
      },
    );
  }

  Widget _buildMonthGroup(
    BuildContext context,
    WidgetRef ref,
    int month,
    List<CompareItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.spacing16,
            AppSizes.spacing16,
            AppSizes.spacing16,
            AppSizes.spacing8,
          ),
          child: Text(
            '$month월',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...items.map(
          (item) => ComparePairCard(
            item: item,
            onRegisterThisYear: item.matchType == MatchType.onlyLastYear &&
                    item.lastYearItem != null
                ? () => _registerThisYear(context, ref, item)
                : null,
          ),
        ),
      ],
    );
  }

  void _registerThisYear(
    BuildContext context,
    WidgetRef ref,
    CompareItem item,
  ) {
    final lastItem = item.lastYearItem;
    if (lastItem == null) return;

    final years = ref.read(selectedYearsProvider);

    // 작년 날짜에서 올해 날짜로 변환
    DateTime scheduledDate;
    try {
      final lastDate = DateTime.parse(lastItem.registrationDate);
      scheduledDate = DateTime(years.thisYear, lastDate.month, lastDate.day);
    } catch (_) {
      scheduledDate = DateTime(years.thisYear, item.sortMonth, 1);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.compareRegisterThisYear),
        content: Text('${lastItem.title}\n\n'
            '${scheduledDate.year}.${scheduledDate.month.toString().padLeft(2, '0')}'
            '.${scheduledDate.day.toString().padLeft(2, '0')} '
            '일정으로 등록하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(schedulesProvider.notifier).createFromImported(
                    lastItem.id,
                    scheduledDate,
                  );
              // 비교 목록도 새로고침
              ref.read(compareItemsProvider.notifier).refresh();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(AppStrings.scheduleConfirm),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
  }

  /// CompareItem에서 일(day) 추출
  int _extractDay(CompareItem item) {
    final dateStr = item.lastYearItem?.registrationDate ??
        item.thisYearItem?.scheduledDate ??
        '';
    try {
      final parts = dateStr.split('-');
      if (parts.length >= 3) return int.parse(parts[2]);
    } catch (_) {}
    return 1;
  }
}

/// 연도 선택 드롭다운
class _YearDropdown extends StatelessWidget {
  const _YearDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(6, (i) => currentYear - 3 + i);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.spacing4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              items: years
                  .map((y) => DropdownMenuItem(
                        value: y,
                        child: Text('$y${AppStrings.compareYearFormat}'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
