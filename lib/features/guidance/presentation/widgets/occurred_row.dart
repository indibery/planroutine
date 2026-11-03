import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/button_semantics.dart';
import '../../../../shared/widgets/sheet_title.dart';
import '../../domain/guidance_content.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_types.dart';
import 'occurred_input.dart';

/// 정리표의 `언제` 행 — 요약 한 줄 + 오른쪽 정밀도. 누르면 시트에서 [OccurredInput]으로 고친다.
/// 시트 안 값은 시트가 따로 들고(부모 setState는 모달을 다시 짓지 않는다) 매 변경을 콜백으로 올린다.
class OccurredRow extends StatelessWidget {
  const OccurredRow({
    super.key,
    required this.current,
    required this.now,
    required this.createdLine,
    required this.precision,
    required this.occurredAt,
    required this.occurredText,
    required this.onPrecision,
    required this.onAt,
    required this.onText,
  });

  /// 요약 글용 현재 내용.
  final GuidanceContent current;
  final DateTime now;
  final String createdLine;
  final OccurredPrecision precision;
  final DateTime occurredAt;
  final String? occurredText;
  final ValueChanged<OccurredPrecision> onPrecision;
  final ValueChanged<DateTime> onAt;
  final ValueChanged<String> onText;

  static const rowKey = Key('occurred_row');

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      builder: (_) => _OccurredSheet(
        createdLine: createdLine,
        precision: precision,
        occurredAt: occurredAt,
        occurredText: occurredText,
        onPrecision: onPrecision,
        onAt: onAt,
        onText: onText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = formatOccurred(current, now: now);
    return ButtonSemantics(
      label: '${GuidanceStrings.labelWhen} $summary ${precision.label}',
      onTap: () => _open(context),
      child: InkWell(
        key: rowKey,
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
          child: Row(
            children: [
              Text(GuidanceStrings.labelWhen, style: AppTextStyles.fieldLabel),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: Text(summary, style: AppTextStyles.bodyL, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: AppSizes.spacing8),
              Text(precision.label, style: AppTextStyles.bodyS),
              Icon(Icons.chevron_right, size: 20, color: AppColors.sub),
            ],
          ),
        ),
      ),
    );
  }
}

class _OccurredSheet extends StatefulWidget {
  const _OccurredSheet({
    required this.createdLine,
    required this.precision,
    required this.occurredAt,
    required this.occurredText,
    required this.onPrecision,
    required this.onAt,
    required this.onText,
  });

  final String createdLine;
  final OccurredPrecision precision;
  final DateTime occurredAt;
  final String? occurredText;
  final ValueChanged<OccurredPrecision> onPrecision;
  final ValueChanged<DateTime> onAt;
  final ValueChanged<String> onText;

  @override
  State<_OccurredSheet> createState() => _OccurredSheetState();
}

class _OccurredSheetState extends State<_OccurredSheet> {
  late OccurredPrecision _precision = widget.precision;
  late DateTime _at = widget.occurredAt;
  late String? _text = widget.occurredText;

  void _changed(OccurredValue v) {
    // 정밀도·시각·글 중 실제로 바뀐 것만 부모에 올린다.
    if (v.precision != _precision) widget.onPrecision(v.precision);
    final at = v.at;
    if (at != null && at != _at) widget.onAt(at);
    if (v.text != _text) widget.onText(v.text ?? '');
    setState(() {
      _precision = v.precision;
      _at = at ?? _at;
      _text = v.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.spacing16,
          AppSizes.spacing16,
          AppSizes.spacing16,
          AppSizes.spacing16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetTitle(GuidanceStrings.labelOccurred),
              const SizedBox(height: AppSizes.spacing12),
              OccurredInput(
                precision: _precision,
                at: _at,
                text: _text,
                onChanged: _changed,
              ),
              const SizedBox(height: AppSizes.spacing12),
              Text(widget.createdLine, style: AppTextStyles.bodyS),
            ],
          ),
        ),
      ),
    );
  }
}
