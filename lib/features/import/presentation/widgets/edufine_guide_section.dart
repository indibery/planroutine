import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';

/// 에듀파인에서 CSV를 받고 아이폰으로 가져오는 방법 안내 접힘 섹션.
///
/// 두 단계로 구성:
///   ① CSV 다운받기 (번호 4단계 + 스크린샷)
///   ② 아이폰으로 가져오기 (A 공유시트 / B 파일 앱 — 둘 중 택1)
class EdufineGuideSection extends StatelessWidget {
  const EdufineGuideSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
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
            children: const [
              _SectionHeader(title: ImportStrings.edufineGuideSection1Title),
              SizedBox(height: AppSizes.spacing8),
              _GuideImage(),
              SizedBox(height: AppSizes.spacing12),
              _NumberedSteps(steps: ImportStrings.edufineGuideSection1Steps),

              SizedBox(height: AppSizes.spacing20),
              _SectionHeader(title: ImportStrings.edufineGuideSection2Title),
              SizedBox(height: AppSizes.spacing4),
              _HintText(text: ImportStrings.edufineGuideSection2Hint),

              SizedBox(height: AppSizes.spacing12),
              _MethodBlock(
                title: ImportStrings.edufineGuideMethodATitle,
                steps: ImportStrings.edufineGuideMethodASteps,
                tip: ImportStrings.edufineGuideMethodATip,
              ),

              SizedBox(height: AppSizes.spacing12),
              _MethodBlock(
                title: ImportStrings.edufineGuideMethodBTitle,
                steps: ImportStrings.edufineGuideMethodBSteps,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.gold,
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 12,
        color: AppColors.sub,
      ),
    );
  }
}

class _GuideImage extends StatelessWidget {
  const _GuideImage();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radius8),
      child: Image.asset(
        'assets/images/edufine_csv_guide.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _NumberedSteps extends StatelessWidget {
  const _NumberedSteps({required this.steps});
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, step) in steps.indexed)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == steps.length - 1 ? 0 : AppSizes.spacing8,
            ),
            child: _StepRow(number: index + 1, text: step),
          ),
      ],
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

/// 방법 A/B — 소제목 + bullet 리스트 + (옵션) 팁 박스.
class _MethodBlock extends StatelessWidget {
  const _MethodBlock({
    required this.title,
    required this.steps,
    this.tip,
  });

  final String title;
  final List<String> steps;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSizes.spacing8),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spacing4),
            child: _BulletRow(text: step),
          ),
        if (tip case final t?) ...[
          const SizedBox(height: AppSizes.spacing8),
          _TipBox(text: t),
        ],
      ],
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7, right: AppSizes.spacing8),
          child: SizedBox(
            width: 4,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Expanded(
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
      ],
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.25),
          width: 0.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: AppColors.gold,
            size: 14,
          ),
          const SizedBox(width: AppSizes.spacing4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                height: 1.45,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
