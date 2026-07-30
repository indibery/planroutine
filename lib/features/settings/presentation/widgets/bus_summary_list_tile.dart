import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../bus/domain/bus_settings.dart';
import '../../../bus/domain/bus_settings_summary.dart';
import '../../../bus/presentation/providers/bus_providers.dart';

/// 설정 탭의 버스 요약 한 줄 — 상세 화면으로 보낸다.
///
/// 모양은 `TrashListTile`과 같다(아이콘 + 제목 + 현재 상태 + chevron). 설정 탭에서
/// 화면으로 나가는 줄은 전부 이 형태여야 눌러야 하는 줄인지 한눈에 보인다.
///
/// **로딩 중에도 기본값으로 그린다** — `BusSettingsTiles`와 같은 이유다. null에
/// `SizedBox.shrink()`를 돌려주면 `SharedPreferences.getInstance()`를 기다리는 한
/// 프레임 동안 이 섹션만 헤더와 Divider 사이가 비어 깜빡인다.
class BusSummaryListTile extends ConsumerWidget {
  const BusSummaryListTile({super.key});

  static const tileKey = Key('bus_summary_tile');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(busSettingsProvider).valueOrNull ?? BusSettings.defaults;

    return ListTile(
      key: tileKey,
      leading: Icon(Icons.directions_bus_outlined, color: AppColors.primary),
      title: const Text(BusStrings.section),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            buildBusSettingsSummary(settings),
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
      onTap: () => context.push(AppRoutes.busSettings),
    );
  }
}
