import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../ai_photo_flow.dart';

/// AI 사진 변환 가져오기 — 파일 없이 클립보드만으로:
/// ① 변환 프롬프트 복사 → AI 앱(사진+프롬프트) → 응답 복사 →
/// ② 붙여넣기 → 미리보기(중복 제외 표시) → 검토 대기(pending) 등록.
///
/// 동작은 [copyAiPhotoPrompt]·[pasteAiSchedulesAndPreview]에 있다 —
/// 입력 탭 히어로와 같은 흐름을 공유한다.
class AiPhotoImportSection extends ConsumerWidget {
  const AiPhotoImportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        border: Border.all(color: AppColors.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ImportStrings.aiTitle,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSizes.spacing4),
          Text(
            ImportStrings.aiDescription,
            style: TextStyle(fontSize: 12, color: AppColors.sub),
          ),
          const SizedBox(height: AppSizes.spacing12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => copyAiPhotoPrompt(context),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text(ImportStrings.aiCopyPrompt),
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => pasteAiSchedulesAndPreview(context, ref),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text(ImportStrings.aiPaste),
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            ImportStrings.aiHint,
            style: TextStyle(fontSize: 11, color: AppColors.faint),
          ),
        ],
      ),
    );
  }
}
