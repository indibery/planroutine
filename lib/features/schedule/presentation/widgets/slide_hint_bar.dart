import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';

const _prefKey = 'schedule_slide_hint_dismissed';

/// 힌트 바 표시 여부 상태
final slideHintVisibleProvider =
    AsyncNotifierProvider<SlideHintNotifier, bool>(SlideHintNotifier.new);

class SlideHintNotifier extends AsyncNotifier<bool> {
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

/// 일정 목록 상단에 노출되는 슬라이드 사용법 안내 바.
///
/// 두 줄로 방향별 액션을 명시:
///   → 오른쪽으로 밀기: 확정 (녹색)
///   ← 왼쪽으로 밀기: 삭제 (빨강)
/// 닫기(✕) 버튼을 누르면 SharedPreferences에 플래그가 저장되어 영구 숨김.
class SlideHintBar extends ConsumerWidget {
  const SlideHintBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleAsync = ref.watch(slideHintVisibleProvider);
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
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        border: Border.all(color: AppColors.line, width: 0.5),
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
                  color: AppColors.inkGreen,
                  icon: Icons.arrow_forward,
                  actionIcon: Icons.check_circle,
                  text: AppStrings.scheduleSlideHintConfirm,
                ),
                SizedBox(height: AppSizes.spacing8),
                _HintRow(
                  color: AppColors.inkRed,
                  icon: Icons.arrow_back,
                  actionIcon: Icons.delete_outline,
                  text: AppStrings.scheduleSlideHintDelete,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () =>
                ref.read(slideHintVisibleProvider.notifier).dismiss(),
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: const Padding(
              padding: EdgeInsets.all(AppSizes.spacing8),
              child: Icon(
                Icons.close,
                size: AppSizes.iconSmall,
                color: AppColors.sub,
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
