import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_gradients.dart';
import '../ai_photo_flow.dart';

/// 입력 탭 히어로 — 이 앱에서 가장 자주 하는 동작.
///
/// 사진 → AI → 붙여넣기는 앱을 **나갔다 오는** 흐름이라, 두 버튼만 세워두면
/// "복사했는데 다음이 뭐지?"가 된다. 그래서 3단(① 프롬프트 · AI 앱 · ② 붙여넣기)을
/// 한 줄에 그려 왕복임을 먼저 보여준다. 가운데 칸은 앱 밖에서 벌어지는 일이라
/// 누를 수 없다.
///
/// 작년 업무 CSV는 학기 초 한 번뿐이라 보조 한 줄 링크로 내린다.
class PhotoInputHero extends ConsumerWidget {
  const PhotoInputHero({super.key, required this.onOpenCsvImport});

  /// 작년 업무 CSV 가져오기 화면으로 이동.
  final VoidCallback onOpenCsvImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.spacing12,
        AppSizes.pagePadding,
        AppSizes.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing16),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(AppSizes.radius14),
              border: Border.all(color: AppColors.line, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.photo_camera_outlined,
                        size: 18, color: AppColors.gold),
                    const SizedBox(width: AppSizes.spacing8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ImportStrings.heroTitle,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            ImportStrings.heroSubtitle,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              color: AppColors.sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing12),
                Row(
                  children: [
                    Expanded(
                      child: _StepButton(
                        label: ImportStrings.heroStepCopy,
                        icon: Icons.copy_rounded,
                        onTap: () => copyAiPhotoPrompt(context),
                      ),
                    ),
                    const _StepArrow(),
                    const _AwayStep(),
                    const _StepArrow(),
                    Expanded(
                      child: _StepButton(
                        label: ImportStrings.heroStepPaste,
                        icon: Icons.auto_awesome,
                        primary: true,
                        onTap: () => pasteAiSchedulesAndPreview(context, ref),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing8),
                Text(
                  ImportStrings.heroHint,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacing4),
          InkWell(
            onTap: onOpenCsvImport,
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing4,
                vertical: AppSizes.spacing8,
              ),
              child: Row(
                children: [
                  Icon(Icons.file_download_outlined,
                      size: 15, color: AppColors.sub),
                  const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: Text(
                      ImportStrings.heroCsvLink,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        color: AppColors.sub,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: AppColors.faint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 누를 수 있는 단계. [primary]는 주 행동(② 붙여넣기) — 골드 채움 + onGold 글씨.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: primary ? AppGradients.gold : null,
          color: primary ? null : AppColors.navySoft,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: primary
              ? null
              : Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: primary ? AppColors.onGold : AppColors.ink,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary ? AppColors.onGold : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 앱 밖에서 벌어지는 가운데 단계 — 누를 수 없다.
class _AwayStep extends StatelessWidget {
  const _AwayStep();

  @override
  Widget build(BuildContext context) {
    return Text(
      ImportStrings.heroStepAway,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.faint,
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Icon(Icons.chevron_right, size: 14, color: AppColors.faint),
    );
  }
}
