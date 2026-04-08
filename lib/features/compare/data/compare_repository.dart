import '../../../core/database/database_helper.dart';
import '../domain/compare_item.dart';

/// 작년/올해 일정 비교 리포지토리
class CompareRepository {
  final DatabaseHelper _dbHelper;

  CompareRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// 작년과 올해 일정을 비교하여 매칭 결과 생성
  Future<List<CompareItem>> generateComparison(
    int lastYear,
    int thisYear,
  ) async {
    final db = await _dbHelper.database;

    // 작년 가져온 일정 조회
    final importedRows = await db.query(
      DatabaseHelper.tableImportedSchedules,
      where: 'source_year = ?',
      whereArgs: [lastYear],
      orderBy: 'registration_date ASC',
    );

    // 올해 일정 조회 (scheduled_date가 올해인 것)
    final scheduleRows = await db.query(
      DatabaseHelper.tableSchedules,
      where: "scheduled_date LIKE ?",
      whereArgs: ['$thisYear%'],
      orderBy: 'scheduled_date ASC',
    );

    final lastYearItems =
        importedRows.map(ImportedScheduleData.fromMap).toList();
    final thisYearItems = scheduleRows.map(ScheduleData.fromMap).toList();

    return _matchItems(lastYearItems, thisYearItems);
  }

  /// 작년/올해 항목 매칭 로직
  List<CompareItem> _matchItems(
    List<ImportedScheduleData> lastYearItems,
    List<ScheduleData> thisYearItems,
  ) {
    final result = <CompareItem>[];
    final matchedThisYear = <int>{};

    for (final lastItem in lastYearItems) {
      final lastMonth = _extractMonth(lastItem.registrationDate);

      // 같은 월에서 제목이 일치하거나 유사한 올해 항목 찾기
      ScheduleData? bestMatch;
      MatchType bestMatchType = MatchType.onlyLastYear;

      for (final thisItem in thisYearItems) {
        if (matchedThisYear.contains(thisItem.id)) continue;

        final thisMonth = _extractMonth(thisItem.scheduledDate);

        if (_isExactMatch(lastItem.title, thisItem.title)) {
          bestMatch = thisItem;
          bestMatchType = MatchType.exact;
          break; // 정확히 일치하면 바로 사용
        }

        if (lastMonth == thisMonth &&
            _isSimilarMatch(lastItem.title, thisItem.title)) {
          bestMatch = thisItem;
          bestMatchType = MatchType.similar;
        }
      }

      if (bestMatch != null) {
        matchedThisYear.add(bestMatch.id);
      }

      result.add(CompareItem(
        lastYearItem: lastItem,
        thisYearItem: bestMatch,
        matchType: bestMatchType,
        sortMonth: lastMonth,
      ));
    }

    // 매칭되지 않은 올해 항목 추가
    for (final thisItem in thisYearItems) {
      if (matchedThisYear.contains(thisItem.id)) continue;

      result.add(CompareItem(
        thisYearItem: thisItem,
        matchType: MatchType.onlyThisYear,
        sortMonth: _extractMonth(thisItem.scheduledDate),
      ));
    }

    // 월 기준 정렬
    result.sort((a, b) => a.sortMonth.compareTo(b.sortMonth));

    return result;
  }

  /// 날짜 문자열에서 월 추출
  int _extractMonth(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length >= 2) {
        return int.parse(parts[1]);
      }
      // yyyy.MM.dd 또는 yyyy/MM/dd 형식도 처리
      final cleaned = dateStr.replaceAll(RegExp(r'[./]'), '-');
      final cleanedParts = cleaned.split('-');
      if (cleanedParts.length >= 2) {
        return int.parse(cleanedParts[1]);
      }
    } catch (_) {}
    return 1;
  }

  /// 정확한 제목 일치 (공백/특수문자 무시)
  bool _isExactMatch(String a, String b) {
    final normalizedA = _normalizeTitle(a);
    final normalizedB = _normalizeTitle(b);
    return normalizedA == normalizedB;
  }

  /// 유사 제목 매칭 (한쪽이 다른 쪽을 포함)
  bool _isSimilarMatch(String a, String b) {
    final normalizedA = _normalizeTitle(a);
    final normalizedB = _normalizeTitle(b);

    if (normalizedA.isEmpty || normalizedB.isEmpty) return false;

    return normalizedA.contains(normalizedB) ||
        normalizedB.contains(normalizedA);
  }

  /// 제목 정규화 (비교용)
  String _normalizeTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^\w가-힣]'), '')
        .toLowerCase();
  }
}
