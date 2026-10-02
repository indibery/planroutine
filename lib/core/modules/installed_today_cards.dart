import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'installed_modules_provider.dart';

/// 오늘 탭 맨 위 — 켠 카드형 기능을 켠 순서대로 놓는다.
///
/// **설치 여부는 여기서만 본다.** 카드 위젯(예: `BusCardHost`)은 올라와 있다는
/// 사실이 곧 켜짐이다. 카드 안에서 비동기 provider를 하나 더 기다리게 하면
/// 촉발 순서에 경합이 생긴다(`BusCardHost.initState`의 주석).
/// 로딩 중에는 아무것도 그리지 않는다 — 꺼 둔 사용자에게 카드가 번쩍이면 안 된다.
class InstalledTodayCards extends ConsumerWidget {
  const InstalledTodayCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(installedModulesProvider).valueOrNull?.cards;
    if (cards == null || cards.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in cards)
          if (m.card case final card?)
            KeyedSubtree(key: ValueKey(m.id), child: card),
      ],
    );
  }
}
