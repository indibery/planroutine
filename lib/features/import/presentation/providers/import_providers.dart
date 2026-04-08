import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/csv_parser.dart';
import '../../data/import_repository.dart';
import '../../domain/imported_schedule.dart';

/// ImportRepository 프로바이더
final importRepositoryProvider = Provider<ImportRepository>((ref) {
  return ImportRepository();
});

/// 가져오기 상태
sealed class ImportState {
  const ImportState();
}

class ImportInitial extends ImportState {
  const ImportInitial();
}

class ImportLoading extends ImportState {
  const ImportLoading();
}

class ImportSuccess extends ImportState {
  const ImportSuccess({
    required this.schedules,
    required this.categorySummary,
    required this.sourceYear,
  });

  final List<ImportedSchedule> schedules;
  final Map<String, int> categorySummary;
  final int sourceYear;
}

class ImportError extends ImportState {
  const ImportError(this.message);

  final String message;
}

/// 가져오기 상태 관리 Notifier
class ImportStateNotifier extends StateNotifier<ImportState> {
  ImportStateNotifier(this._repository) : super(const ImportInitial());

  final ImportRepository _repository;

  /// 파일 선택 후 CSV 가져오기
  Future<void> pickAndImportCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      state = const ImportLoading();

      final file = result.files.first;
      final path = file.path;
      if (path == null) {
        state = const ImportError('파일 경로를 읽을 수 없습니다');
        return;
      }

      // 파일 바이트 읽기 및 디코딩
      final bytes = await File(path).readAsBytes();
      final csvParser = const CsvParser();
      final csvContent = csvParser.decodeBytes(bytes);

      // 파싱 및 DB 저장
      final schedules = await _repository.importFromCsv(csvContent);

      if (schedules.isEmpty) {
        state = const ImportError('가져올 일정이 없습니다');
        return;
      }

      // 연도 추출 (첫 번째 항목 기준)
      final sourceYear = schedules.first.sourceYear ?? DateTime.now().year;

      // 카테고리 요약
      final categorySummary = await _repository.getCategorySummary(sourceYear);

      state = ImportSuccess(
        schedules: schedules,
        categorySummary: categorySummary,
        sourceYear: sourceYear,
      );
    } catch (e) {
      state = ImportError('가져오기 중 오류: $e');
    }
  }

  /// 상태 초기화
  void reset() {
    state = const ImportInitial();
  }
}

/// ImportState 프로바이더
final importStateProvider =
    StateNotifierProvider<ImportStateNotifier, ImportState>((ref) {
  final repository = ref.watch(importRepositoryProvider);
  return ImportStateNotifier(repository);
});

/// 저장된 일정 목록 프로바이더 (연도/카테고리 필터)
final importedSchedulesProvider = FutureProvider.family<
    List<ImportedSchedule>, ({int? year, String? category})>(
  (ref, filter) async {
    final repository = ref.watch(importRepositoryProvider);
    return repository.getImportedSchedules(
      year: filter.year,
      category: filter.category,
    );
  },
);

/// 가져온 연도 목록 프로바이더
final importedYearsProvider = FutureProvider<List<int>>((ref) async {
  final repository = ref.watch(importRepositoryProvider);
  return repository.getImportedYears();
});
