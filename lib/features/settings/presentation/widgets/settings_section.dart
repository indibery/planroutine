import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/section_header.dart';

/// 설정 화면의 한 섹션 — 헤더(title·subtitle) + 본문 + 하단 Divider 세트를
/// 한 번에 묶는다. settings_screen.dart 전역에서 반복되던 Padding+SectionHeader+
/// Divider 3종 세트를 한 줄로 줄여 가독성을 높인다.
///
/// 마지막 섹션처럼 divider가 필요 없는 경우 [showDivider]=false를 넘긴다.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pagePadding,
          ),
          child: SectionHeader(title: title, subtitle: subtitle),
        ),
        child,
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}
