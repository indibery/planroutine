import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_gradients.dart';
import '../ai_photo_flow.dart';
import '../../../schedule/domain/entry_kind.dart';
import '../../../../shared/widgets/pill_chip.dart';

/// 입력 탭 히어로 — 이 앱에서 가장 자주 하는 동작.
///
/// 사진 → AI → 붙여넣기는 앱을 **나갔다 오는** 흐름이라, 두 버튼만 세워두면
/// "복사했는데 다음이 뭐지?"가 된다. 그래서 3단(① 프롬프트 · AI 앱 · ② 붙여넣기)을
/// 한 줄에 그려 왕복임을 먼저 보여준다. 가운데 칸은 앱 밖에서 벌어지는 일이라
/// 누를 수 없다.
///
/// 작년 업무 CSV는 학기 초 한 번뿐이라 보조 한 줄 링크로 내린다.
class PhotoInputHero extends ConsumerStatefulWidget {
  const PhotoInputHero({super.key, required this.onOpenCsvImport});

  /// 작년 업무 CSV 가져오기 화면으로 이동.
  final VoidCallback onOpenCsvImport;

  /// 종류 세그먼트. 라벨은 `행사 일정표`/`업무 쪽지`로 소스 문서를 말하므로
  /// `EntryKind.label`(업무·행사)로 찾으면 검토 목록의 배지와 섞인다.
  static const sourceKindKey = Key('ai_source_kind');

  @override
  ConsumerState<PhotoInputHero> createState() => _PhotoInputHeroState();
}

class _PhotoInputHeroState extends ConsumerState<PhotoInputHero> {
  /// 찍은 사진이 무엇인가 — **프롬프트와 등록 종류를 함께 결정한다.**
  ///
  /// 화면 수명 동안만 유지한다(저장하지 않는다). 대부분의 사용자가 학기 초에 일정표를
  /// 한 번 넣으므로 기본값은 행사이고, 쪽지는 그때그때 고른다.
  EntryKind _source = EntryKind.event;

  @override
  Widget build(BuildContext context) {
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
                    Icon(
                      Icons.photo_camera_outlined,
                      size: 18,
                      color: AppColors.gold,
                    ),
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
                const SizedBox(height: AppSizes.spacing8),
                // **①보다 위에 둔다.** 프롬프트가 이 선택에 따라 달라지므로, 복사한
                // 뒤에 고르면 엉뚱한 프롬프트를 AI에 붙여넣게 된다.
                //
                // `SegmentedSettingRow`를 쓰지 않는다 — 설정 화면 한 줄용(아이콘 +
                // 라벨 + 세그먼트)이라 좁은 히어로 카드에서 154px 넘쳤다(폭 가드가
                // 잡았다). 리포의 선택 가능한 칩은 전부 `PillChip`이고, 칩 라벨이
                // 스스로 무엇을 찍는지 말하므로 별도 라벨 줄도 필요 없다.
                Wrap(
                  key: PhotoInputHero.sourceKindKey,
                  spacing: AppSizes.spacing8,
                  runSpacing: AppSizes.spacing4,
                  children: [
                    PillChip(
                      label: ImportStrings.aiSourceEvent,
                      selected: _source == EntryKind.event,
                      onTap: () => setState(() => _source = EntryKind.event),
                    ),
                    PillChip(
                      label: ImportStrings.aiSourceTask,
                      selected: _source == EntryKind.task,
                      onTap: () => setState(() => _source = EntryKind.task),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing8),
                Row(
                  children: [
                    Expanded(
                      child: _StepButton(
                        label: ImportStrings.heroStepCopy,
                        icon: Icons.copy_rounded,
                        onTap: () => copyAiPhotoPrompt(context, kind: _source),
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
                        onTap: () => pasteAiSchedulesAndPreview(
                          context,
                          ref,
                          kind: _source,
                        ),
                      ),
                    ),
                  ],
                ),
                // **안내 두 줄을 없앴다.** 종류 칩이 한 줄을 쓰면서 입력 탭이 21px
                // 넘쳤고(폭·높이 가드가 잡았다), 이 힌트가 가장 값이 낮았다 —
                // 세 곳과 중복이다: 3단 버튼이 흐름을 말하고, 칩이 무엇을 찍는지
                // 말하고, 복사 스낵바가 `AI 앱에 …사진과 함께 붙여넣으세요`를
                // 그대로 말한다. 이 앱은 같은 말을 두 곳에 쓰지 않는다(진행도 텍스트·
                // 필터 요약 중복 제거와 같은 규율).
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          // 보조 경로지만 학기 초에 반드시 한 번은 찾아야 한다 —
          // 옅은 글씨 한 줄이면 못 찾는다. 테두리로 눌 수 있음을 보이되,
          // 히어로(골드 채움)와는 위계를 벌려 주·보조가 뒤바뀌지 않게 한다.
          InkWell(
            onTap: widget.onOpenCsvImport,
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing12,
                vertical: AppSizes.spacing12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radius12),
                border: Border.all(color: AppColors.line, width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.file_download_outlined,
                    size: 17,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: Text(
                      ImportStrings.heroCsvLink,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.sub),
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
