import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../import/presentation/providers/import_providers.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../data/app_reset_repository.dart';
import '../../data/schedule_csv_exporter.dart';

/// 전체 초기화 저장소 프로바이더
final appResetRepositoryProvider = Provider<AppResetRepository>((ref) {
  return AppResetRepository();
});

/// 전체 초기화 액션 상태
sealed class ResetState {
  const ResetState();
}

class ResetIdle extends ResetState {
  const ResetIdle();
}

class ResetInProgress extends ResetState {
  const ResetInProgress();
}

class ResetSuccess extends ResetState {
  const ResetSuccess();
}

class ResetFailure extends ResetState {
  const ResetFailure(this.message);
  final String message;
}

/// 전체 초기화를 수행하고 관련 프로바이더를 무효화한다.
class AppResetNotifier extends StateNotifier<ResetState> {
  AppResetNotifier(this._ref) : super(const ResetIdle());

  final Ref _ref;

  Future<void> resetAll() async {
    state = const ResetInProgress();
    try {
      await _ref.read(appResetRepositoryProvider).resetAll();

      // DB가 비워졌으므로 캐시된 목록/상태를 모두 갱신한다.
      _ref.invalidate(schedulesProvider);
      _ref.invalidate(selectedMonthEventsProvider);
      _ref.read(importStateProvider.notifier).reset();

      state = const ResetSuccess();
    } catch (e) {
      state = ResetFailure(e.toString());
    }
  }
}

final appResetProvider =
    StateNotifierProvider<AppResetNotifier, ResetState>((ref) {
  return AppResetNotifier(ref);
});

/// CSV 내보내기 프로바이더
final scheduleCsvExporterProvider = Provider<ScheduleCsvExporter>((ref) {
  return ScheduleCsvExporter();
});
