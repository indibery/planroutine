import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/domain/time_range.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: 'B정류장',
  nodeNo: 2251,
  cityCode: 31010,
  routeIds: {'R1'},
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(ProviderContainer, BusSettingsNotifier)> boot() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(busSettingsProvider.future);
    return (container, container.read(busSettingsProvider.notifier));
  }

  test('처음에는 기본값이다 — 꺼져 있고 모양은 간단히', () async {
    final (container, _) = await boot();
    final s = container.read(busSettingsProvider).requireValue;
    expect(s.enabled, isFalse);
    expect(s.style, BusCardStyle.text);
  });

  test('슬롯을 저장하면 방향별로 들어간다', () async {
    final (container, notifier) = await boot();
    await notifier.setStop(CommuteDirection.toHome, _stop);

    final s = container.read(busSettingsProvider).requireValue;
    expect(s.arrival?.nodeId, 'GGB201000156');
    expect(s.arrival?.routeIds, {'R1'});
    expect(s.departure, isNull);
  });

  test('저장한 값이 새 컨테이너에서도 읽힌다', () async {
    final (_, notifier) = await boot();
    await notifier.setEnabled(true);
    await notifier.setStyle(BusCardStyle.axis);

    final fresh = ProviderContainer();
    addTearDown(fresh.dispose);
    final s = await fresh.read(busSettingsProvider.future);
    expect(s.enabled, isTrue);
    expect(s.style, BusCardStyle.axis);
  });

  test('겹치는 시간대는 저장되지 않는다', () async {
    final (container, notifier) = await boot();
    final before = container.read(busSettingsProvider).requireValue.toHomeRange;

    await notifier.setRange(
      CommuteDirection.toHome,
      const TimeRange.hm(8, 0, 18, 0), // 출근 07:00-08:30과 겹친다
    );

    final after = container.read(busSettingsProvider).requireValue.toHomeRange;
    expect(after.label, before.label, reason: '겹치면 이전 값을 유지한다');
  });

  test('뒤집힌 시간대는 저장되지 않는다', () async {
    final (container, notifier) = await boot();
    await notifier.setRange(CommuteDirection.toWork, const TimeRange.hm(9, 0, 7, 0));
    expect(
      container.read(busSettingsProvider).requireValue.toWorkRange.label,
      '07:00 – 08:30',
    );
  });

  test('override는 저장되고 지워진다', () async {
    final (container, notifier) = await boot();
    final at = DateTime(2026, 7, 28, 8, 35);

    await notifier.setOverride(expanded: true, at: at);
    var s = container.read(busSettingsProvider).requireValue;
    expect(s.overrideAt, at);
    expect(s.overrideExpanded, isTrue);

    await notifier.clearOverride();
    s = container.read(busSettingsProvider).requireValue;
    expect(s.overrideAt, isNull);
    expect(s.overrideExpanded, isFalse);
  });

  test('겹친 시간대를 읽으면 시간대만 기본값으로 되돌려 저장한다 — 나머지는 보존', () async {
    // `setRange`가 저장을 막으므로 정상 UI로는 만들 수 없는 값이다(prefs 손상·수동
    // 편집·향후 스키마 변경). 그냥 들고 있으면 `resolveBusDisplay`가 override를
    // 읽기도 전에 접힘을 반환해 카드가 영구히 접히고 제목줄 탭이 no-op가 된다.
    final broken = BusSettings.defaults.copyWith(
      enabled: true,
      departure: _stop,
      arrival: _stop,
      style: BusCardStyle.axis,
      toHomeRange: const TimeRange.hm(8, 0, 18, 0), // 출근 07:00–08:30과 겹친다
      overrideAt: DateTime(2026, 7, 28, 8, 35),
      overrideExpanded: true,
    );
    SharedPreferences.setMockInitialValues({
      'bus_settings_v1': jsonEncode(broken.toJson()),
    });

    final (container, _) = await boot();
    final s = container.read(busSettingsProvider).requireValue;

    expect(s.rangesValid, isTrue, reason: '읽은 즉시 유효한 상태가 된다');
    expect(s.toWorkRange.label, '07:00 – 08:30');
    expect(s.toHomeRange.label, '16:00 – 18:00');

    // **시간대 두 개만** 되돌린다. 여기서 하나라도 날아가면 정류장을 다시 등록해야
    // 하는데, 사용자는 자기가 무엇을 잘못했는지도 모른다.
    expect(s.enabled, isTrue);
    expect(s.departure?.nodeId, _stop.nodeId);
    expect(s.arrival?.nodeId, _stop.nodeId);
    expect(s.style, BusCardStyle.axis);
    expect(s.overrideExpanded, isTrue);
    expect(s.overrideAt, DateTime(2026, 7, 28, 8, 35));

    // 복구를 prefs에 쓴다 — 안 쓰면 앱을 켤 때마다 같은 판정을 반복하고, 그 사이
    // 저장되는 다른 설정이 겹친 시간대를 다시 데려온다.
    final fresh = ProviderContainer();
    addTearDown(fresh.dispose);
    final reread = await fresh.read(busSettingsProvider.future);
    expect(reread.toHomeRange.label, '16:00 – 18:00');
  });

  test('손상된 값이면 기본값으로 폴백한다', () async {
    SharedPreferences.setMockInitialValues({'bus_settings_v1': '{ not json'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final s = await container.read(busSettingsProvider.future);
    expect(s.enabled, isFalse);
  });
}
