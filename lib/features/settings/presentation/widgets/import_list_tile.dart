import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';

/// 작년 일정 가져오기 — 설정 탭의 1줄 진입점. 탭하면 전용 ImportScreen으로 push.
class ImportListTile extends StatelessWidget {
  const ImportListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.upload_file, color: AppColors.primary),
      title: const Text(SettingsStrings.importSection),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.import),
    );
  }
}
