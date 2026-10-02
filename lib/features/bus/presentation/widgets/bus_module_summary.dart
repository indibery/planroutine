import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/bus_settings.dart';
import '../../domain/bus_settings_summary.dart';
import '../providers/bus_providers.dart';

/// `기능 관리`의 켜진 버스 행 부제. 등록부(`moduleCatalog`)가 이 위젯을 들고 있다.
///
/// 글자 모양은 지정하지 않는다 — `ListTile` 부제 자리의 기본 스타일을 따라야 다른
/// 기능의 부제(설명 문구)와 같아 보인다.
///
/// **로딩 중에도 기본값으로 그린다.** null에 빈 위젯을 돌려주면
/// `SharedPreferences.getInstance()`를 기다리는 한 프레임 동안 부제가 비어 행 높이가 튄다.
class BusModuleSummary extends ConsumerWidget {
  const BusModuleSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(busSettingsProvider).valueOrNull ?? BusSettings.defaults;
    return Text(buildBusSettingsSummary(settings));
  }
}
