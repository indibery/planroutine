import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/button_semantics.dart';
import '../../../../shared/widgets/sheet_title.dart';
import '../../domain/guidance_content.dart';
import '../../domain/guidance_logic.dart';
import 'occurred_input.dart';

/// 정리표의 `언제` 행 — 요약 한 줄 + 오른쪽 정밀도. 누르면 시트에서 [OccurredInput]으로 고친다.
/// 시트 안 값은 시트가 따로 들고(부모 setState는 모달을 다시 짓지 않는다) 매 변경을 콜백으로 올린다.
class OccurredRow extends StatelessWidget {
  const OccurredRow({
    super.key,
    required this.current,
    required this.now,
    required this.createdLine,
    required this.value,
    required this.onChanged,
  });

  /// 요약 글용 현재 내용.
  final GuidanceContent current;
  final DateTime now;
  final String createdLine;

  /// 부모가 들고 있는 값 그대로(대략으로 적은 기록은 `at`이 null).
  final OccurredValue value;

  /// 시트 안에서 바뀔 때마다 새 값 전체를 올린다.
  final ValueChanged<OccurredValue> onChanged;

  /// 정리표 행 이름 칸 폭 — 모든 행의 값이 같은 세로선에서 시작하게 화면 표와 나눠 쓴다.
  static const nameColumnWidth = 52.0;

  static const rowKey = Key('occurred_row');

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      builder: (_) => _OccurredSheet(
        createdLine: createdLine,
        value: value,
        now: now,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = formatOccurred(current, now: now);
    return ButtonSemantics(
      label: '${GuidanceStrings.labelWhen} $summary ${value.precision.label}',
      onTap: () => _open(context),
      child: InkWell(
        key: rowKey,
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
          child: Row(
            children: [
              SizedBox(
                width: nameColumnWidth,
                child: Text(
                  GuidanceStrings.labelWhen,
                  style: AppTextStyles.fieldLabel,
                ),
              ),
              Expanded(
                child: Text(
                  summary,
                  style: AppTextStyles.bodyL,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSizes.spacing8),
              Text(
                value.precision.label,
                style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
              ),
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
    required this.value,
    required this.now,
    required this.onChanged,
  });

  final String createdLine;
  final OccurredValue value;
  final DateTime now;
  final ValueChanged<OccurredValue> onChanged;

  @override
  State<_OccurredSheet> createState() => _OccurredSheetState();
}

class _OccurredSheetState extends State<_OccurredSheet> {
  // 시트에 보이는 값 — 시각이 비어 있는 기록(대략)은 지금으로 시작한다. 바뀔 때 이 값 그대로 부모에
  // 올라가야 저장 때 시트에서 본 날짜가 남는다.
  late OccurredValue _v = OccurredValue(
    precision: widget.value.precision,
    at: widget.value.at ?? widget.now,
    text: widget.value.text,
  );

  void _changed(OccurredValue v) {
    widget.onChanged(v);
    setState(() => _v = v);
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
                precision: _v.precision,
                at: _v.at,
                text: _v.text,
                onChanged: _changed,
              ),
              const SizedBox(height: AppSizes.spacing12),
              Text(
                widget.createdLine,
                style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
