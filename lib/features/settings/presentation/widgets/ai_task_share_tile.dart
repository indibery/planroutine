import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/ai_task_share_provider.dart';

/// 설정 탭 고급 섹션 — AI 자동화 공유 토글(기본 OFF).
/// ON이면 캘린더 이벤트 편집에 'AI로 보내기' 액션이 노출된다.
class AiTaskShareTile extends ConsumerWidget {
  const AiTaskShareTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(aiTaskShareEnabledProvider).valueOrNull ?? false;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(Icons.auto_awesome, color: AppColors.gold),
      title: const Text(SettingsStrings.aiShareToggleTitle),
      subtitle: Text(
        SettingsStrings.aiShareToggleSubtitle,
        style: TextStyle(fontSize: 12, color: AppColors.sub),
      ),
      value: enabled,
      onChanged: (v) => ref.read(aiTaskShareEnabledProvider.notifier).set(v),
    );
  }
}
