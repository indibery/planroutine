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

/// 슬라이드 사용법 안내 바 (최초 1회, 닫기 시 영구 숨김)
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
        AppSizes.spacing8,
        AppSizes.spacing16,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing12,
        vertical: AppSizes.spacing8,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.swipe,
            size: AppSizes.iconSmall,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSizes.spacing8),
          const Expanded(
            child: Text(
              AppStrings.scheduleSlideHint,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: () => ref
                .read(slideHintVisibleProvider.notifier)
                .dismiss(),
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: const Padding(
              padding: EdgeInsets.all(AppSizes.spacing4),
              child: Icon(
                Icons.close,
                size: AppSizes.iconSmall,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
