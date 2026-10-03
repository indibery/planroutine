import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/guidance_types.dart';

/// 테두리형 배지 — 글자색과 테두리가 같다. 대비는 글자색 대 배경으로 재면 된다.
class _OutlineBadge extends StatelessWidget {
  const _OutlineBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(AppSizes.radius4),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class GuidanceKindBadge extends StatelessWidget {
  const GuidanceKindBadge(this.kind, {super.key});
  final GuidanceKind kind;

  static Color colorOf(GuidanceKind kind) =>
      kind == GuidanceKind.infringement ? AppColors.inkRed : AppColors.guidanceKindBlue;

  @override
  Widget build(BuildContext context) => _OutlineBadge(label: kind.label, color: colorOf(kind));
}

/// `진행 중`은 기본 상태라 아무것도 그리지 않는다.
class GuidanceStatusBadge extends StatelessWidget {
  const GuidanceStatusBadge(this.status, {super.key});
  final GuidanceStatus status;

  /// 두 상태 모두 `sub` — inkGreen은 라이트 카드 위 3.43:1로 미달이다. 상태는 글자로 구분된다.
  static Color colorOf(GuidanceStatus status) => AppColors.sub;

  @override
  Widget build(BuildContext context) => switch (status) {
    GuidanceStatus.open => const SizedBox.shrink(),
    GuidanceStatus.closedAtSchool => _OutlineBadge(
      label: GuidanceStrings.statusClosedShort,
      color: colorOf(status),
    ),
    GuidanceStatus.transferred => _OutlineBadge(
      label: GuidanceStrings.statusTransferredShort,
      color: colorOf(status),
    ),
  };
}
