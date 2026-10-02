// lib/features/settings/presentation/widgets/modules_list_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/modules/installed_modules_provider.dart';
import '../../../../core/router/app_router.dart';

/// 설정 탭의 `기능 관리` 한 줄. 모양은 `TrashListTile`과 같다
/// (아이콘 + 제목 + 현재 상태 + chevron).
class ModulesListTile extends ConsumerWidget {
  const ModulesListTile({super.key});

  static const tileKey = Key('modules_tile');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(installedModulesProvider).valueOrNull;
    final count = resolved == null
        ? 0
        : [...resolved.tabs, ...resolved.cards].where((m) => !m.fixed).length;

    return ListTile(
      key: tileKey,
      leading: Icon(Icons.extension_outlined, color: AppColors.primary),
      title: const Text(SettingsStrings.modulesTitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            SettingsStrings.modulesSummary(count),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(width: AppSizes.spacing4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => context.push(AppRoutes.modules),
    );
  }
}
