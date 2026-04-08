import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/compare_repository.dart';
import '../../domain/compare_item.dart';

/// 비교 리포지토리 프로바이더
final compareRepositoryProvider = Provider<CompareRepository>((ref) {
  return CompareRepository();
});

/// 선택된 연도 쌍 (작년, 올해)
final selectedYearsProvider = StateProvider<({int lastYear, int thisYear})>(
  (ref) {
    final now = DateTime.now();
    return (lastYear: now.year - 1, thisYear: now.year);
  },
);

/// 비교 항목 목록
final compareItemsProvider =
    AsyncNotifierProvider<CompareItemsNotifier, List<CompareItem>>(
  CompareItemsNotifier.new,
);

/// 비교 항목 관리 Notifier
class CompareItemsNotifier extends AsyncNotifier<List<CompareItem>> {
  @override
  Future<List<CompareItem>> build() async {
    final years = ref.watch(selectedYearsProvider);
    final repository = ref.watch(compareRepositoryProvider);
    return repository.generateComparison(years.lastYear, years.thisYear);
  }

  /// 비교 결과 새로고침
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
