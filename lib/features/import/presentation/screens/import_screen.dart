import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../domain/imported_schedule.dart';
import '../providers/import_providers.dart';
import '../widgets/edufine_guide_section.dart';
import '../widgets/import_summary_card.dart';

/// **작년 업무 CSV** 전용 풀스크린.
///
/// 학교일정 사진 AI는 입력 탭 히어로가 맡는다 — 여기서 또 보여주면
/// "작년 업무 가져오기"를 누르고 들어온 사람에게 엉뚱한 화면이 된다.
///
/// 상단에 1-2-3 스테퍼가 항상 노출되어 어느 단계인지 한눈에 보이고,
/// 그 아래 state별 본문이 바뀐다.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(importStateProvider);
    final activeStep = _stepFor(importState);

    // 등록이 끝나면 이 화면에 머물 이유가 없다 — 검토 목록으로 바로 돌려보낸다.
    // 건수는 입력 탭의 `검토 대기 N`이 이미 말해주므로 스낵바로만 알린다.
    ref.listen<ImportState>(importStateProvider, (prev, next) {
      if (next is! ImportRegistered) return;
      final messenger = ScaffoldMessenger.of(context);
      ref.read(importStateProvider.notifier).reset();
      if (context.canPop()) {
        context.pop();
      } else {
        // 공유시트로 곧바로 열린 경우엔 pop할 스택이 없다.
        context.go(AppRoutes.schedule);
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(
            ImportStrings.registeredSnack(next.created, next.skipped),
          ),
        ));
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ImportStrings.screenTitle,
          style: AppTextStyles.heading,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.spacing16,
              AppSizes.pagePadding,
              AppSizes.spacing8,
            ),
            child: ImportSteps(activeStep: activeStep),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: switch (importState) {
                ImportInitial() => _buildInitialView(context, ref),
                ImportLoading() => _buildLoadingView(context),
                ImportSuccess(
                  :final schedules,
                  :final categorySummary,
                  :final sourceYear,
                  :final nonProductionSkipped,
                ) =>
                  _buildSuccessView(
                    context,
                    ref,
                    schedules,
                    categorySummary,
                    sourceYear,
                    nonProductionSkipped,
                  ),
                // 등록 직후 위 listen이 pop하므로 그릴 것이 없다.
                ImportRegistered() => const SizedBox.shrink(),
                ImportError(:final message) =>
                  _buildErrorView(context, ref, message),
              },
            ),
          ),
        ],
      ),
    );
  }

  int _stepFor(ImportState state) => switch (state) {
        ImportInitial() || ImportError() => 0,
        ImportLoading() || ImportSuccess() => 1,
        ImportRegistered() => 2,
      };

  Widget _buildInitialView(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(AppSizes.radius14),
              border: Border.all(color: AppColors.lineStrong, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ImportStrings.csvTitle,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSizes.spacing4),
                Text(
                  ImportStrings.description,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: AppSizes.spacing16),
                Center(
                  child: GoldGradientButton(
                    label: ImportStrings.selectFile,
                    icon: Icons.file_open,
                    onPressed: () {
                      ref
                          .read(importStateProvider.notifier)
                          .pickAndImportCsv();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          const EdufineGuideSection(),
        ],
      ),
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing32),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppColors.gold),
          const SizedBox(height: AppSizes.spacing12),
          Text(
            ImportStrings.parsing,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: AppColors.sub,
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
    int nonProductionSkipped,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImportSummaryCard(
          totalCount: schedules.length,
          categorySummary: categorySummary,
          sourceYear: sourceYear,
          nonProductionSkipped: nonProductionSkipped,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16,
            vertical: AppSizes.spacing8,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: GoldGradientButton(
                  label: ImportStrings.registerAll,
                  icon: Icons.playlist_add_check,
                  onPressed: () =>
                      _confirmRegister(context, ref, schedules, sourceYear),
                ),
              ),
              const SizedBox(width: AppSizes.spacing8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(importStateProvider.notifier).reset(),
                  child: const Text(AppStrings.cancel),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    WidgetRef ref,
    String message,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.inkRed),
              const SizedBox(width: AppSizes.spacing8),
              Text(
                ImportStrings.failed,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          GoldGradientButton(
            label: AppStrings.retry,
            icon: Icons.refresh,
            onPressed: () =>
                ref.read(importStateProvider.notifier).pickAndImportCsv(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRegister(
    BuildContext context,
    WidgetRef ref,
    List<ImportedSchedule> schedules,
    int sourceYear,
  ) async {
    await ref
        .read(importStateProvider.notifier)
        .registerAllAsSchedules(schedules, sourceYear);
    ref.invalidate(schedulesProvider);
  }
}

/// 가져오기 3단계 인디케이터 — ① 파일 선택 · ② 분석 · ③ 등록.
class ImportSteps extends StatelessWidget {
  const ImportSteps({super.key, required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepDot(index: 0, active: activeStep >= 0),
        _StepLine(active: activeStep >= 1),
        _StepDot(index: 1, active: activeStep >= 1),
        _StepLine(active: activeStep >= 2),
        _StepDot(index: 2, active: activeStep >= 2),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.active});

  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.gold : Colors.transparent,
        border: Border.all(
          color: active ? AppColors.gold : AppColors.faint,
          width: 1,
        ),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.navy : AppColors.faint,
        ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: AppSizes.spacing4),
        color: active ? AppColors.gold : AppColors.faint,
      ),
    );
  }
}
