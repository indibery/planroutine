import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

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
          SegmentedButton<T>(
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // 채움(선택) 세그먼트는 goldFill + onGold — 라이트에서 gold(딥골드)를
              // 채움에 쓰면 navy 텍스트와 대비가 낮다(3.57:1). goldFill로 8.37:1.
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? AppColors.onGold
                      : AppColors.sub),
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? AppColors.goldFill
                      : Colors.transparent),
              side: WidgetStatePropertyAll(
                BorderSide(color: AppColors.lineStrong, width: 0.5),
              ),
            ),
            segments: segments,
            selected: {selected},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }
}
