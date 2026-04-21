import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// 좌우 스와이프 액션 안내용 공용 힌트 바.
///
/// `prefKey`별로 독립적인 숨김 상태를 SharedPreferences에 저장한다.
/// 두 줄(→/←) 각각에 아이콘·라벨·색상을 지정해 호출부가 의미를 결정한다.
class SlideHintBar extends ConsumerWidget {
  const SlideHintBar({
    super.key,
    required this.prefKey,
    required this.leftIcon,
    required this.leftText,
    required this.leftColor,
    required this.rightIcon,
    required this.rightText,
    required this.rightColor,
  });

  final String prefKey;
  final IconData leftIcon;
  final String leftText;
  final Color leftColor;
  final IconData rightIcon;
  final String rightText;
  final Color rightColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = slideHintVisibleProviderFamily(prefKey);
    final visibleAsync = ref.watch(provider);
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _HintRow(
                  color: leftColor,
                  directionIcon: Icons.arrow_forward,
                  actionIcon: leftIcon,
                  text: leftText,
                ),
                const SizedBox(height: AppSizes.spacing8),
                _HintRow(
                  color: rightColor,
                  directionIcon: Icons.arrow_back,
                  actionIcon: rightIcon,
                  text: rightText,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => ref.read(provider.notifier).dismiss(),
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
    required this.directionIcon,
    required this.actionIcon,
    required this.text,
  });

  final Color color;
  final IconData directionIcon;
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
          child: Icon(directionIcon, size: 14, color: color),
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

/// prefKey별 독립적인 숨김 상태 — family 로 prefKey마다 notifier 1개.
final slideHintVisibleProviderFamily =
    AsyncNotifierProvider.family<SlideHintNotifier, bool, String>(
  SlideHintNotifier.new,
);

class SlideHintNotifier extends FamilyAsyncNotifier<bool, String> {
  @override
  Future<bool> build(String prefKey) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(prefKey) ?? false);
  }

  Future<void> dismiss() async {
    state = const AsyncData(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(arg, true);
  }
}
