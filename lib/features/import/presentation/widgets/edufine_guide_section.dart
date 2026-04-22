import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';

/// 에듀파인에서 CSV를 다운받는 방법을 안내하는 접힘 섹션.
///
/// Import 풀스크린 Initial 뷰의 '파일 선택' 카드 아래에 배치된다.
/// 첫 사용자는 펼쳐서 6단계 + 스크린샷으로 확인하고, 반복 사용자는
/// 접힌 채로 무시할 수 있다.
class EdufineGuideSection extends StatelessWidget {
  const EdufineGuideSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      // ExpansionTile 기본 divider 제거 — 바깥 카드 테두리와 중복 방지
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glass,
            border: Border.all(color: AppColors.line, width: 0.6),
            borderRadius: BorderRadius.circular(AppSizes.radius14),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.cardPadding,
              vertical: AppSizes.spacing4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSizes.cardPadding,
              0,
              AppSizes.cardPadding,
              AppSizes.cardPadding,
            ),
            iconColor: AppColors.sub,
            collapsedIconColor: AppColors.sub,
            leading: const Icon(
              Icons.help_outline,
              color: AppColors.gold,
              size: 20,
            ),
            title: const Text(
              ImportStrings.edufineGuideTitle,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            children: [
              // 스크린샷 — 에듀파인 annotation 이미지
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
                child: Image.asset(
                  'assets/images/edufine_csv_guide.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppSizes.spacing12),
              // 6단계 숫자 리스트
              for (final (index, step)
                  in ImportStrings.edufineGuideSteps.indexed)
                Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        index == ImportStrings.edufineGuideSteps.length - 1
                            ? 0
                            : AppSizes.spacing8,
                  ),
                  child: _StepRow(number: index + 1, text: step),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.gold, width: 1),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spacing8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                height: 1.45,
                color: AppColors.sub,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
