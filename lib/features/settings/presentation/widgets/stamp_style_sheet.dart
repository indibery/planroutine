import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../today/domain/stamp_settings.dart';
import '../../../today/presentation/widgets/completion_seal.dart';
import '../providers/stamp_settings_provider.dart';

/// 도장 모양 고르기 — 2열 그리드 바텀시트.
///
/// **설정 탭에 칩 `Wrap`으로 두지 않는다.** 도장이 4종이 되자 라벨 옆에 못 들어가
/// 줄이 둘로 갈라졌고(같은 화면의 `화면 테마`는 한 줄인데 이 줄만 두 줄), 도장은
/// 앞으로 더 늘어나는 축이다. 그래서 규칙이 이렇게 바뀌었다 —
/// **개수가 고정된 설정은 세그먼트, 늘어나는 설정은 시트.**
/// 시트는 개수가 늘어도 자기 높이만 자라고 설정 화면은 변하지 않는다.
///
/// 미리보기는 [CompletionSeal]을 **그대로** 쓴다. 전용 위젯을 새로 그리면 실제
/// 찍히는 도장과 반드시 어긋난다(`test/tools/seal_preview.dart`도 같은 방식이다).
class StampStyleSheet extends ConsumerWidget {
  const StampStyleSheet({super.key});

  /// 선택지 하나를 찾는 키.
  ///
  /// 라벨 문자열로 찾으면 안 된다 — 글자 도장(`완료`·`결재`)은 미리보기 도장 **안에도**
  /// 같은 글자를 그리므로 `find.text`가 두 개를 문다.
  static Key optionKey(SealStyle style) => Key('stamp_option_${style.name}');

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      // 기본값(false)은 시트를 화면 top까지 뻗게 하고 그 모드에서는 MediaQuery의
      // top padding이 제거돼 안쪽 SafeArea가 무력해진다 — 이 리포에는 그 함정에
      // 물려 제목이 다이나믹 아일랜드와 겹쳤던 전례가 있다(버스 확인 시트).
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius18),
        ),
      ),
      builder: (_) => const StampStyleSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        (ref.watch(stampSettingsProvider).valueOrNull ?? StampSettings.defaults)
            .style;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          AppSizes.spacing12,
          AppSizes.pagePadding,
          AppSizes.spacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.faint,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              SettingsStrings.stampStyleSheetTitle,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            // 2열 고정 — 모양이 늘어도 열은 그대로고 줄만 늘어난다. 폭을 직접
            // 계산해 넘기는 이유는 `Wrap`만 쓰면 칸 폭이 라벨 길이를 따라
            // 들쭉날쭉해지기 때문이다(`도마뱀`이 `완료`보다 넓다).
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = AppSizes.spacing8;
                final cellWidth = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final style in SealStyle.values)
                      SizedBox(
                        width: cellWidth,
                        child: _Option(
                          style: style,
                          selected: style == selected,
                          onTap: () async {
                            await ref
                                .read(stampSettingsProvider.notifier)
                                .setStyle(style);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 선택지 한 칸 — 미리보기 도장 + 이름 (+ 골랐으면 체크).
class _Option extends StatelessWidget {
  const _Option({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final SealStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: StampStyleSheet.optionKey(style),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radius12),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          // 선택 표시는 색 + 형태 둘 다다. 체크(아래)가 비색상 단서 —
          // 캘린더 목록에서 ★를 남긴 것과 같은 이유다.
          color: selected
              ? AppColors.goldFill.withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // 실제 오늘 탭에 찍히는 위젯 그대로. 안착 상태로 고정해 그린다.
            CompletionSeal(
              animation: const AlwaysStoppedAnimation(1),
              style: style,
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Text(
                style.label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.gold : AppColors.ink,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 18, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
