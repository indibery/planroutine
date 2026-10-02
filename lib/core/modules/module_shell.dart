import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/main_shell.dart';
import 'installed_modules_provider.dart';
import 'module_rules.dart';

/// 등록부를 읽어 `MainShell`에 탭 목록을 넘긴다. `MainShell`이 feature를 모르게
/// 두려고 이 한 겹을 core에 둔다.
///
/// 로딩 중에는 저장값 없이 정리한 값(고정 4탭)을 쓴다 — 탭바가 한 프레임이라도
/// 비면 하단이 깜빡인다.
class ModuleShell extends ConsumerWidget {
  const ModuleShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved =
        ref.watch(installedModulesProvider).valueOrNull ??
        resolveModules(ref.watch(moduleCatalogProvider), null);
    return MainShell(
      tabs: [for (final m in resolved.tabs) ?m.tab],
      child: child,
    );
  }
}
