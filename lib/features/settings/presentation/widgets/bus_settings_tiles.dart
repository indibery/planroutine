import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../bus/domain/bus_card_style.dart';
import '../../../bus/domain/bus_settings.dart';
import '../../../bus/domain/commute_direction.dart';
import '../../../bus/domain/time_range.dart';
import '../../../bus/presentation/providers/bus_providers.dart';

/// `설정 > 버스 도착` 섹션 본문.
///
/// 스위치가 꺼져 있으면 나머지 줄을 감춘다 — 기본이 꺼짐이라 이 기능을 쓰지 않는
/// 사용자에게 설정 탭도 지금과 거의 같게 보인다.
class BusSettingsTiles extends ConsumerWidget {
  const BusSettingsTiles({super.key});

  static const switchKey = Key('bus_show_switch');
  static const departureKey = Key('bus_slot_departure');
  static const arrivalKey = Key('bus_slot_arrival');
  static const styleKey = Key('bus_style_row');
  static const rangeToWorkKey = Key('bus_range_to_work');
  static const rangeToHomeKey = Key('bus_range_to_home');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // **로딩 중에도 기본값으로 그린다.** null에 `SizedBox.shrink()`를 돌려주면
    // `SharedPreferences.getInstance()`를 기다리는 한 프레임 동안 제목·부제·Divider만
    // 있고 스위치가 없는 빈 섹션이 보인다 — 같은 화면의 도장·알림·테마 섹션은
    // 전부 defaults로 즉시 그리므로 이 섹션 하나만 깜빡인다. 기본값이 `enabled:
    // false`라 아래 감춤 로직도 그대로 맞다.
    final settings =
        ref.watch(busSettingsProvider).valueOrNull ?? BusSettings.defaults;

    final notifier = ref.read(busSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // **썸 색을 지정하지 않는다.** `app_theme`의 `switchTheme`이 ON 썸을 navy,
        // 트랙을 gold로 잡아 대비를 맞춰 뒀다. 여기서 `activeThumbColor`를 주면
        // Flutter의 해상 순서(위젯 > 테마)가 그 navy를 밀어내는데, 다크에서는
        // `goldFill`과 `gold`가 같은 값(#E0B96A)이라 **ON이 썸 없는 단색 골드 알약**이
        // 된다(M3 스위치는 selected 그림자·외곽선이 없어 형태 단서도 0이다).
        // 같은 ListView의 형제 스위치(도장·알림)는 지정하지 않아 정상으로 보였다 —
        // 기능 전체를 켜는 유일한 관문만 다르게 보이던 셈이다.
        SwitchListTile(
          key: switchKey,
          value: settings.enabled,
          onChanged: notifier.setEnabled,
          title: Text(BusStrings.showTitle, style: _titleStyle),
          subtitle: Text(
            settings.enabled
                ? BusStrings.showSubtitleOn
                : BusStrings.showSubtitleOff,
            style: _subStyle,
          ),
        ),
        if (settings.enabled) ...[
          _slotTile(
            context,
            key: departureKey,
            title: BusStrings.slotDeparture,
            hint: BusStrings.slotDepartureHint,
            value: settings.departure?.nodeNm,
            direction: CommuteDirection.toWork,
          ),
          _slotTile(
            context,
            key: arrivalKey,
            title: BusStrings.slotArrival,
            hint: BusStrings.slotArrivalHint,
            value: settings.arrival?.nodeNm,
            direction: CommuteDirection.toHome,
          ),
          _styleRow(settings, notifier),
          _rangeTile(
            context,
            key: rangeToWorkKey,
            title: BusStrings.rangeToWork,
            hint: BusStrings.rangeHintToWork,
            range: settings.toWorkRange,
            direction: CommuteDirection.toWork,
            notifier: notifier,
          ),
          _rangeTile(
            context,
            key: rangeToHomeKey,
            title: BusStrings.rangeToHome,
            hint: BusStrings.rangeHintToHome,
            range: settings.toHomeRange,
            direction: CommuteDirection.toHome,
            notifier: notifier,
          ),
        ],
      ],
    );
  }

  TextStyle get _titleStyle => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  TextStyle get _subStyle => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        color: AppColors.sub,
      );

  Widget _slotTile(
    BuildContext context, {
    required Key key,
    required String title,
    required String hint,
    required String? value,
    required CommuteDirection direction,
  }) {
    return ListTile(
      key: key,
      title: Text(title, style: _titleStyle),
      subtitle: Text(hint, style: _subStyle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value ?? BusStrings.slotEmpty,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: value == null ? AppColors.faint : AppColors.sub,
            ),
          ),
          const SizedBox(width: AppSizes.spacing4),
          Icon(Icons.chevron_right, size: 20, color: AppColors.faint),
        ],
      ),
      onTap: () => context.push('${AppRoutes.busStops}?slot=${direction.name}'),
    );
  }

  Widget _styleRow(BusSettings settings, BusSettingsNotifier notifier) {
    return Padding(
      key: styleKey,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.spacing8,
        AppSizes.pagePadding,
        AppSizes.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(BusStrings.cardStyle, style: _titleStyle),
          Text(BusStrings.cardStyleHint, style: _subStyle),
          const SizedBox(height: AppSizes.spacing8),
          SegmentedButton<BusCardStyle>(
            segments: BusCardStyle.values
                .map((s) => ButtonSegment(value: s, label: Text(s.label)))
                .toList(),
            selected: {settings.style},
            showSelectedIcon: false,
            onSelectionChanged: (set) => notifier.setStyle(set.first),
          ),
        ],
      ),
    );
  }

  Widget _rangeTile(
    BuildContext context, {
    required Key key,
    required String title,
    required String hint,
    required TimeRange range,
    required CommuteDirection direction,
    required BusSettingsNotifier notifier,
  }) {
    return ListTile(
      key: key,
      title: Text(title, style: _titleStyle),
      subtitle: Text(hint, style: _subStyle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            range.label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(width: AppSizes.spacing4),
          Icon(Icons.chevron_right, size: 20, color: AppColors.faint),
        ],
      ),
      onTap: () => _pickRange(context, range, direction, notifier),
    );
  }

  /// 시작·종료를 차례로 고른다. 겹치거나 뒤집히면 `setRange`가 저장을 거부하고
  /// 스낵바로 알린다.
  Future<void> _pickRange(
    BuildContext context,
    TimeRange current,
    CommuteDirection direction,
    BusSettingsNotifier notifier,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.startMinutes ~/ 60,
        minute: current.startMinutes % 60,
      ),
    );
    if (start == null || !context.mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.endMinutes ~/ 60,
        minute: current.endMinutes % 60,
      ),
    );
    if (end == null || !context.mounted) return;

    final next = TimeRange.hm(start.hour, start.minute, end.hour, end.minute);
    if (!next.isValid) {
      _toast(context, BusStrings.rangeInverted);
      return;
    }

    // `notifier.state`를 읽지 않는다 — riverpod 2.6.1에서 @protected +
    // @visibleForTesting이라 위젯에서 읽으면 flutter analyze가 깨진다.
    // setRange가 저장 여부를 직접 돌려주게 해 라벨 비교 자체를 없앤다.
    final applied = await notifier.setRange(direction, next);
    if (!context.mounted) return;
    if (!applied) _toast(context, BusStrings.rangeOverlap);
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
