import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/guidance_types.dart';

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

  void _emit({OccurredPrecision? precision, DateTime? at, bool clearAt = false}) => widget.onChanged(
    OccurredValue(
      precision: precision ?? widget.precision,
      at: clearAt ? null : (at ?? widget.at),
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
        SegmentedButton<OccurredPrecision>(
          showSelectedIcon: false,
          segments: [
            for (final p in OccurredPrecision.values)
              ButtonSegment(value: p, label: Text(p.label, key: OccurredInput.precisionKey(p))),
          ],
          selected: {widget.precision},
          onSelectionChanged: (s) {
            final p = s.first;
            // 대략으로 바꾸면 시각을 비운다 — 남겨 두면 저장할 때 정밀도와 어긋난다.
            _emit(precision: p, clearAt: p == OccurredPrecision.approx, at: at ?? DateTime.now());
          },
        ),
        const SizedBox(height: AppSizes.spacing8),
        if (widget.precision == OccurredPrecision.approx)
          TextField(
            key: OccurredInput.approxKey,
            controller: _approx,
            decoration: const InputDecoration(hintText: GuidanceStrings.approxHint),
            onChanged: (_) => _emit(),
          )
        else
          Wrap(
            spacing: AppSizes.spacing8,
            children: [
              OutlinedButton.icon(
                key: OccurredInput.dateKey,
                onPressed: _pickDate,
                icon: const Icon(Icons.event, size: AppSizes.iconSmall),
                label: Text(
                  at == null ? GuidanceStrings.pickDate : DateFormat('y. M. d. (E)', 'ko').format(at),
                ),
              ),
              if (widget.precision == OccurredPrecision.exact)
                OutlinedButton.icon(
                  key: OccurredInput.timeKey,
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: AppSizes.iconSmall),
                  label: Text(at == null ? GuidanceStrings.pickTime : DateFormat('HH:mm').format(at)),
                ),
            ],
          ),
      ],
    );
  }
}
