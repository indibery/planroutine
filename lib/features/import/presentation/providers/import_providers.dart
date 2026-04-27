import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/csv_parser.dart';
import '../../data/import_repository.dart';
import '../../domain/imported_schedule.dart';
import '../../../calendar/data/calendar_repository.dart';
import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../schedule/data/schedule_repository.dart';
import '../../../schedule/domain/schedule.dart';
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

/// 등록 완료 상태 — 사용자가 "확인" 후 결과를 명시적으로 확인할 수 있도록 유지
class ImportRegistered extends ImportState {
  const ImportRegistered({
    required this.created,
    required this.skipped,
    required this.sourceYear,
  });

  final int created;
  final int skipped;
  final int sourceYear;
}

/// 가져오기 상태 관리 Notifier
class ImportStateNotifier extends StateNotifier<ImportState> {
  ImportStateNotifier(
    this._ref,
    this._repository,
    this._scheduleRepository,
    this._calendarRepository,
  ) : super(const ImportInitial());

  final Ref _ref;
  final ImportRepository _repository;
  final ScheduleRepository _scheduleRepository;
  final CalendarRepository _calendarRepository;

  /// 파일 피커로 CSV 선택 후 가져오기. 내부적으로 [importFromPath] 위임.
  Future<void> pickAndImportCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) {
      state = const ImportError('파일 경로를 읽을 수 없습니다');
      return;
    }
    await importFromPath(path);
  }

  /// 경로가 이미 주어진 상태에서 CSV 가져오기.
  ///
  /// 다른 앱(카카오톡/메일/파일 앱)에서 공유받은 파일과 file_picker 결과를 같은
  /// 파싱 파이프라인으로 처리하기 위해 분리했다.
  ///
  /// 플랜루틴 자체 export CSV(헤더에 "상태" 포함)는 바로 확정 일정 + 캘린더
  /// 이벤트로 복원 → `ImportRegistered`. 원본 생산문서등록대장 CSV는
  /// `ImportSuccess` → 사용자가 "전체 등록" 버튼 탭.
  Future<void> importFromPath(String path) async {
    try {
      state = const ImportLoading();

      final bytes = await File(path).readAsBytes();
      final csvParser = const CsvParser();
      final csvContent = await csvParser.decodeBytes(bytes);
      final parsed = csvParser.parseWithMetadata(csvContent);

      if (parsed.schedules.isEmpty) {
        state = const ImportError('가져올 일정이 없습니다');
        return;
      }

      if (parsed.isPlanRoutineFormat) {
        await _importPlanRoutineCsv(parsed);
        return;
      }

      final schedules = await _repository.importFromCsv(csvContent);
      if (schedules.isEmpty) {
        state = const ImportError('가져올 일정이 없습니다');
        return;
      }
      final sourceYear = schedules.first.sourceYear ?? DateTime.now().year;
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

  /// 플랜루틴 export CSV를 직접 schedules + calendar_events로 복원한다.
  Future<void> _importPlanRoutineCsv(ParsedCsv parsed) async {
    final now = DateTime.now().toIso8601String();
    var created = 0;
    var skipped = 0;

    for (final row in parsed.schedules) {
      final key = '${row.title}|${row.registrationDate}';
      final isConfirmed = parsed.confirmedTitles.contains(key);
      final description = parsed.descriptionsByTitle[key];

      final scheduleId = await _scheduleRepository.insertConfirmedOrPending(
        Schedule(
          title: row.title,
          description: description,
          scheduledDate: row.registrationDate,
          category: row.category,
          status:
              isConfirmed ? ScheduleStatus.confirmed : ScheduleStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (scheduleId < 0) {
        skipped++;
        continue;
      }
      created++;

      // 확정 상태면 캘린더 이벤트 자동 생성 (내부에서 중복 체크)
      if (isConfirmed) {
        await _calendarRepository.createFromSchedule(scheduleId);
      }
    }

    // 일정 탭 + 캘린더 즉시 반영
    _ref.invalidate(schedulesProvider);
    _ref.invalidate(monthEventsByYearMonthProvider);
    _ref.invalidate(selectedMonthEventsProvider);

    state = ImportRegistered(
      created: created,
      skipped: skipped,
      sourceYear: _extractYear(parsed.schedules.first.registrationDate),
    );
  }

  int _extractYear(String dateStr) {
    if (dateStr.length < 4) return DateTime.now().year;
    return int.tryParse(dateStr.substring(0, 4)) ?? DateTime.now().year;
  }

  /// 가져온 일정을 올해 일정으로 일괄 등록 (중복 자동 스킵) → 등록 완료 상태로 전환
  Future<void> registerAllAsSchedules(
    List<ImportedSchedule> schedules,
    int sourceYear,
  ) async {
    final thisYear = DateTime.now().year;
    final items = <({int importedId, DateTime date})>[];

    for (final schedule in schedules) {
      if (schedule.id == null) continue;
      final date = _convertToThisYear(schedule.registrationDate, thisYear);
      items.add((importedId: schedule.id!, date: date));
    }

    final result = await _scheduleRepository.createBulkFromImported(items);
    state = ImportRegistered(
      created: result.created,
      skipped: result.skipped,
      sourceYear: sourceYear,
    );
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
  final calendarRepo = ref.watch(calendarRepositoryProvider);
  return ImportStateNotifier(ref, importRepo, scheduleRepo, calendarRepo);
});

