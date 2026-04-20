import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';

const _prefKey = 'calendar_slide_hint_dismissed';

/// 힌트 바 표시 여부 상태
final calendarSlideHintVisibleProvider =
    AsyncNotifierProvider<CalendarSlideHintNotifier, bool>(
  CalendarSlideHintNotifier.new,
);

class CalendarSlideHintNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefKey) ?? false);
  }

  Future<void> dismiss() async {
    state = const AsyncData(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }
}

/// 캘린더 이벤트 목록 상단 안내 바 — 양방향 스와이프의 의미를 시각적으로 전달.
///
///   → 오른쪽: Google 저장 (파랑)
///   ← 왼쪽: 완료/완료 취소 (녹색)
///
/// 닫기(✕) 탭 시 SharedPreferences에 플래그 저장해 영구 숨김.
class CalendarSlideHintBar extends ConsumerWidget {
  const CalendarSlideHintBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleAsync = ref.watch(calendarSlideHintVisibleProvider);
    final visible = visibleAsync.valueOrNull ?? false;
    if (!visible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.spacing16,
        AppSizes.spacing12,
        AppSizes.spacing16,
        AppSizes.spacing4,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing12,
        AppSizes.spacing12,
        AppSizes.spacing4,
        AppSizes.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _HintRow(
                  color: AppColors.primary,
                  icon: Icons.arrow_forward,
                  actionIcon: Icons.cloud_upload,
                  text: AppStrings.calendarSwipeHintGoogle,
                ),
                SizedBox(height: AppSizes.spacing8),
                _HintRow(
                  color: AppColors.statusConfirmed,
                  icon: Icons.arrow_back,
                  actionIcon: Icons.check_circle,
                  text: AppStrings.calendarSwipeHintComplete,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () =>
                ref.read(calendarSlideHintVisibleProvider.notifier).dismiss(),
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: const Padding(
              padding: EdgeInsets.all(AppSizes.spacing8),
              child: Icon(
                Icons.close,
                size: AppSizes.iconSmall,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({
    required this.color,
    required this.icon,
    required this.actionIcon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final IconData actionIcon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing8,
            vertical: AppSizes.spacing4,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radius4),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: AppSizes.spacing8),
        Icon(actionIcon, size: 16, color: color),
        const SizedBox(width: AppSizes.spacing4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
