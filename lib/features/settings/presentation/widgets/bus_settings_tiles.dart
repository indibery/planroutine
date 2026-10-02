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

/// `기능 관리 › 출퇴근 버스` 상세 화면의 본문 — 정류장·카드 모양·시간대.
///
/// **켜짐 스위치가 없다**(2026-10-03 설계). 이 화면은 버스가 켜져 있을 때만
/// 기능 관리 행의 `›`로 들어오므로, 켜고 끄는 곳은 그 행의 스위치 하나다.
class BusSettingsTiles extends ConsumerWidget {
  const BusSettingsTiles({super.key});

  static const departureKey = Key('bus_slot_departure');
  static const arrivalKey = Key('bus_slot_arrival');
  static const styleKey = Key('bus_style_row');
  static const rangeToWorkKey = Key('bus_range_to_work');
  static const rangeToHomeKey = Key('bus_range_to_home');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // **로딩 중에도 기본값으로 그린다.** null에 `SizedBox.shrink()`를 돌려주면
    // `SharedPreferences.getInstance()`를 기다리는 한 프레임 동안 빈 화면이 보인다 —
    // 같은 앱의 도장·알림·테마 섹션은 전부 defaults로 즉시 그린다.
    final settings =
        ref.watch(busSettingsProvider).valueOrNull ?? BusSettings.defaults;

    final notifier = ref.read(busSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    );
  }

  TextStyle get _titleStyle => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  TextStyle get _subStyle =>
      TextStyle(fontFamily: 'Pretendard', fontSize: 13, color: AppColors.sub);

  Widget _slotTile(
    BuildContext context, {
    required Key key,
    required String title,
    required String hint,
    required String? value,
    required CommuteDirection direction,
  }) {
    // **`trailing`의 폭을 묶어야 한다.** `ListTile`은 trailing에 제약을 주지 않아
    // 긴 정류장 이름이 가로를 다 먹고 `title`·`subtitle`을 두 글자 폭으로 짓눌렀다 —
    // `도착지`가 세로로 여섯 줄이 됐다(실기기 신고 2026-07-30, 실측
    // `석수체육공원.자동차학원.원태우지사의거지`).
    //
    // 카드 제목줄은 같은 함정을 `Expanded` + `ellipsis`로 이미 막고 있었다
    // (`bus_arrival_card.dart`) — 이 행만 빠져 있었다.
    //
    // 45%인 이유: 남는 55%가 `학교 근처에서 타는 정류장`(부제 중 가장 긴 것)을
    // 320pt에서 한 줄에 담는다. 가드 테스트가 320·390·430pt를 훑는다.
    return LayoutBuilder(
      builder: (context, constraints) => ListTile(
        key: key,
        title: Text(title, style: _titleStyle),
        subtitle: Text(hint, style: _subStyle),
        trailing: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value ?? BusStrings.slotEmpty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    color: value == null ? AppColors.faint : AppColors.sub,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spacing4),
              Icon(Icons.chevron_right, size: 20, color: AppColors.faint),
            ],
          ),
        ),
        onTap: () =>
            context.push('${AppRoutes.busStops}?slot=${direction.name}'),
      ),
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
