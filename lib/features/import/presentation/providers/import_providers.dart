import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/csv_parser.dart';
import '../../data/import_repository.dart';
import '../../domain/imported_schedule.dart';
import '../../../schedule/data/schedule_repository.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
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
  ImportStateNotifier(this._repository, this._scheduleRepository)
      : super(const ImportInitial());

  final ImportRepository _repository;
  final ScheduleRepository _scheduleRepository;

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

      // 파일 바이트 읽기 및 디코딩 (UTF-8 → EUC-KR 순서로 시도)
      final bytes = await File(path).readAsBytes();
      final csvParser = const CsvParser();
      final csvContent = await csvParser.decodeBytes(bytes);

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

  /// 가져온 일정을 올해 일정으로 일괄 등록 (중복 자동 스킵)
  Future<({int created, int skipped})> registerAllAsSchedules(
    List<ImportedSchedule> schedules,
  ) async {
    final thisYear = DateTime.now().year;
    final items = <({int importedId, DateTime date})>[];

    for (final schedule in schedules) {
      if (schedule.id == null) continue;
      final date = _convertToThisYear(schedule.registrationDate, thisYear);
      items.add((importedId: schedule.id!, date: date));
    }

    return _scheduleRepository.createBulkFromImported(items);
  }

  /// 등록일자를 올해 날짜로 변환
  DateTime _convertToThisYear(String dateStr, int year) {
    try {
      final parsed = DateTime.parse(dateStr);
      return DateTime(year, parsed.month, parsed.day);
    } catch (_) {
      return DateTime(year, 1, 1);
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
  final importRepo = ref.watch(importRepositoryProvider);
  final scheduleRepo = ref.watch(scheduleRepositoryProvider);
  return ImportStateNotifier(importRepo, scheduleRepo);
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

/// 선택 모드 상태
final importSelectModeProvider = StateProvider<bool>((ref) => false);

/// 선택된 일정 ID 목록
final selectedImportIdsProvider = StateProvider<Set<int>>((ref) => {});
