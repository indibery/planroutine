import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/bus_settings.dart';
import '../../domain/bus_settings_summary.dart';
import '../providers/bus_providers.dart';

/// `기능 관리`에서 켜진 버스 아래 `상세 설정` 줄의 오른쪽 요약. 등록부
/// (`moduleCatalog`)가 이 위젯을 들고 있다.
///
/// 글자 모양은 지정하지 않는다 — 기능 관리 화면이 요약 자리의 스타일을 정해야 다른
/// 기능의 요약과 같아 보인다.
///
/// **로딩 중에도 기본값으로 그린다.** null에 빈 위젯을 돌려주면
/// `SharedPreferences.getInstance()`를 기다리는 한 프레임 동안 요약이 비어 깜빡인다.
class BusModuleSummary extends ConsumerWidget {
  const BusModuleSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(busSettingsProvider).valueOrNull ?? BusSettings.defaults;
    return Text(buildBusSettingsSummary(settings));
  }
}
