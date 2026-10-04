import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/guidance_types.dart';
import '../../../../shared/widgets/picker_field_tile.dart';
import '../../../../shared/widgets/segmented_button_semantics.dart';

class OccurredValue {
  const OccurredValue({required this.precision, this.at, this.text});
  final OccurredPrecision precision;
  final DateTime? at;
  final String? text;
}

/// 사건 시각 — 정확히(날짜+시각) / 날짜만 / 대략(글). 날짜·시각 고르기는 탭의 중첩
/// 내비게이터에 띄운다(`useRootNavigator: false`, 가드).
class OccurredInput extends StatefulWidget {
  const OccurredInput({
    super.key,
    required this.precision,
    required this.onChanged,
    this.at,
    this.text,
  });

  final OccurredPrecision precision;
  final DateTime? at;
  final String? text;
  final ValueChanged<OccurredValue> onChanged;

  static Key precisionKey(OccurredPrecision p) => Key('occurred_${p.dbValue}');
  static const dateKey = Key('occurred_date');
  static const timeKey = Key('occurred_time');
  static const approxKey = Key('occurred_approx');

  @override
  State<OccurredInput> createState() => _OccurredInputState();
}

class _OccurredInputState extends State<OccurredInput> {
  late final _approx = TextEditingController(text: widget.text ?? '');

  @override
  void dispose() {
    _approx.dispose();
    super.dispose();
  }

  void _emit({OccurredPrecision? precision, DateTime? at}) => widget.onChanged(
    OccurredValue(
      precision: precision ?? widget.precision,
      at: at ?? widget.at,
      text: _approx.text,
    ),
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final base = widget.at ?? now;
    final d = await showDatePicker(
      context: context,
      useRootNavigator: false,
      initialDate: base,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (d == null) return;
    _emit(at: DateTime(d.year, d.month, d.day, base.hour, base.minute));
  }

  Future<void> _pickTime() async {
    final base = widget.at ?? DateTime.now();
    final t = await showTimePicker(
      context: context,
      useRootNavigator: false,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (t == null) return;
    _emit(at: DateTime(base.year, base.month, base.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final at = widget.at;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButtonSemantics<OccurredPrecision>(child: SegmentedButton<OccurredPrecision>(
          showSelectedIcon: false,
          segments: [
            for (final p in OccurredPrecision.values)
              ButtonSegment(value: p, label: Text(p.label, key: OccurredInput.precisionKey(p))),
          ],
          selected: {widget.precision},
          onSelectionChanged: (s) {
            final p = s.first;
            // 마지막 시각은 화면 상태에 남긴다 — 대략 → 정확히로 되돌릴 때 근거 시각이 바뀌면 안 된다.
            // 저장할 때 `normalized()`가 정밀도에 맞춰 버린다(대략이면 시각 null).
            _emit(precision: p, at: at ?? DateTime.now());
          },
        )),
        const SizedBox(height: AppSizes.spacing8),
        if (widget.precision == OccurredPrecision.approx)
          TextField(
            key: OccurredInput.approxKey,
            controller: _approx,
            decoration: const InputDecoration(hintText: GuidanceStrings.approxHint),
            onChanged: (_) => _emit(),
          )
        else
          // 일정 편집 시트와 같은 `라벨 … 값` 타일(2026-10-04 디자인 점검). 예전에는 골드 테두리
          // 알약 버튼이라 한 앱에 날짜 입력이 두 모양이었다.
          Column(
            children: [
              PickerFieldTile(
                key: OccurredInput.dateKey,
                label: GuidanceStrings.pickDate,
                value: at == null ? GuidanceStrings.notPicked : DateFormat('y. M. d. (E)', 'ko').format(at),
                icon: Icons.calendar_today,
                onTap: _pickDate,
              ),
              if (widget.precision == OccurredPrecision.exact) ...[
                const SizedBox(height: AppSizes.spacing8),
                PickerFieldTile(
                  key: OccurredInput.timeKey,
                  label: GuidanceStrings.pickTime,
                  value: at == null ? GuidanceStrings.notPicked : DateFormat('HH:mm').format(at),
                  icon: Icons.schedule,
                  onTap: _pickTime,
                ),
              ],
            ],
          ),
      ],
    );
  }
}
