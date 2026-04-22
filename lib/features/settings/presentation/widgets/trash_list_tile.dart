import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../trash/presentation/providers/trash_providers.dart';

/// 휴지통 ListTile — 건수 배지 + chevron으로 휴지통 화면 진입.
class TrashListTile extends ConsumerWidget {
  const TrashListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(trashSnapshotProvider);
    final count = snapshotAsync.valueOrNull?.total ?? 0;
    return ListTile(
      leading: const Icon(Icons.delete_outline, color: AppColors.primary),
      title: const Text(AppStrings.trashTitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing8,
                vertical: AppSizes.spacing4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          const SizedBox(width: AppSizes.spacing4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => context.push(AppRoutes.trash),
    );
  }
}
