import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import 'segmented_button_semantics.dart';

/// 설정 한 줄 = 아이콘 + 라벨 + 세그먼트 선택기.
///
/// 화면 테마·완료 도장처럼 "몇 개 중 하나"를 고르는 설정이 공유한다. 특히 세그먼트의
/// 채움 색 규칙이 여기 한 곳에만 있어야 한다 — 설정 화면에 두 개가 서로 다른 모양으로
/// 놓이는 일을 막는다.
class SegmentedSettingRow<T> extends StatelessWidget {
  const SegmentedSettingRow({
    super.key,
    required this.icon,
    required this.label,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSizes.spacing16),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          SegmentedButtonSemantics<T>(
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              // 색·글자는 테마의 segmentedButtonTheme(골드 채움 규칙)이 정한다.
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: segments,
              selected: {selected},
              onSelectionChanged: (selection) => onChanged(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}
