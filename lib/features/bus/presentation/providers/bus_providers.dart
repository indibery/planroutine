import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/bus_api_client.dart';
import '../../domain/bus_card_style.dart';
import '../../domain/bus_settings.dart';
import '../../domain/bus_stop.dart';
import '../../domain/commute_direction.dart';
import '../../domain/time_range.dart';

const _prefsKey = 'bus_settings_v1';

/// TAGO 클라이언트 — **`autoDispose`가 아니다.**
///
/// 메모리 캐시를 이 인스턴스가 들고 있어서, 탭을 옮겼다 오늘 탭으로 돌아올 때
/// 빈 카드가 깜빡이지 않게 하려면 살아남아야 한다. 카드 provider만 autoDispose다.
final busApiClientProvider = Provider<BusApiClient>((ref) => BusApiClient());

/// 버스 설정 — 오늘 탭이 소비하고 설정 탭이 변경한다. SharedPreferences 저장.
final busSettingsProvider =
    AsyncNotifierProvider<BusSettingsNotifier, BusSettings>(
  BusSettingsNotifier.new,
);

class BusSettingsNotifier extends AsyncNotifier<BusSettings> {
  @override
  Future<BusSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return BusSettings.defaults;
    try {
      return BusSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 손상된 값이면 기본값으로
      return BusSettings.defaults;
    }
  }

  BusSettings get _current => state.valueOrNull ?? BusSettings.defaults;

  Future<void> setEnabled(bool value) => _save(_current.copyWith(enabled: value));

  Future<void> setStyle(BusCardStyle style) =>
      _save(_current.copyWith(style: style));

  /// 슬롯 교체 — 저장과 동시에 캐시를 버린다.
  ///
  /// 캐시를 남기면 카드가 옛 정류장 값을 최대 30초 더 보여준다. `/bus/stops`는
  /// push 라우트라 pop 후 stale이 되기 쉬운 경로다(CLAUDE.md의 push 함정).
  Future<void> setStop(CommuteDirection direction, BusStop stop) {
    ref.read(busApiClientProvider).invalidate();
    return _save(direction == CommuteDirection.toWork
        ? _current.copyWith(departure: stop)
        : _current.copyWith(arrival: stop));
  }

  /// 시간대 변경. **겹치거나 뒤집히면 저장하지 않고 false를 돌려준다.**
  ///
  /// bool을 돌려주는 이유: 설정 화면이 거부 여부를 알아야 스낵바를 띄울 수 있는데,
  /// `notifier.state`는 riverpod 2.6.1에서 @protected라 위젯에서 읽으면 analyze가
  /// 깨진다. 저장한 쪽이 결과를 말해주는 편이 라벨을 비교하는 것보다 정확하다.
  Future<bool> setRange(CommuteDirection direction, TimeRange range) async {
    final next = direction == CommuteDirection.toWork
        ? _current.copyWith(toWorkRange: range)
        : _current.copyWith(toHomeRange: range);
    if (!next.rangesValid) return false;
    await _save(next);
    return true;
  }

  Future<void> setOverride({required bool expanded, required DateTime at}) =>
      _save(_current.copyWith(overrideAt: at, overrideExpanded: expanded));

  Future<void> clearOverride() => _save(_current.clearOverride());

  Future<void> _save(BusSettings next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
  }
}
