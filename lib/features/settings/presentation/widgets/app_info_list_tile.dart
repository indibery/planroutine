import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/app_info_provider.dart';

/// 앱 정보 — 앱 이름 + 버전/빌드 번호 표시 (정보성, 탭 비활성).
class AppInfoListTile extends ConsumerWidget {
  const AppInfoListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(appInfoProvider);
    return ListTile(
      leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
      title: Text(infoAsync.valueOrNull?.appName ?? AppStrings.appName),
      subtitle: Text(
        infoAsync.when(
          data: (info) => info.displayVersion,
          loading: () => AppStrings.loading,
          error: (_, _) => AppStrings.error,
        ),
      ),
    );
  }
}
