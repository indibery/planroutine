import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/domain/time_range.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: '수원시청',
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

  test('손상된 값이면 기본값으로 폴백한다', () async {
    SharedPreferences.setMockInitialValues({'bus_settings_v1': '{ not json'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final s = await container.read(busSettingsProvider.future);
    expect(s.enabled, isFalse);
  });
}
