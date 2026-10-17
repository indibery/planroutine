import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
import '../../data/sb_result.dart';
import '../../domain/schoolbook_link.dart';
import '../providers/schoolbook_providers.dart';

/// 학교 링크 입력칸 + `연결`. 탭의 첫 화면과 상세 설정의 `학교 링크 바꾸기`가 함께 쓴다.
class SchoolbookConnectView extends ConsumerStatefulWidget {
  const SchoolbookConnectView({super.key, this.onConnected});

  /// 연결이 끝난 뒤(상세 설정은 이것으로 입력칸을 닫는다).
  final VoidCallback? onConnected;

  static const fieldKey = Key('schoolbook_connect_field');
  static const connectKey = Key('schoolbook_connect_button');

  @override
  ConsumerState<SchoolbookConnectView> createState() => _SchoolbookConnectViewState();
}

class _SchoolbookConnectViewState extends ConsumerState<SchoolbookConnectView> {
  final _field = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy) return;
    final code = parseSchoolCode(_field.text);
    if (code == null) {
      setState(() => _error = SchoolbookStrings.connectNotFound);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // 연결되면 이 화면이 사라지므로 알림 자리를 먼저 붙잡아 둔다
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(schoolbookApiClientProvider).login(code);
    final info = result.value;
    if (result.outcome == SbOutcome.ok && info != null) {
      // 응답의 코드 대신 입력에서 뽑은 코드를 저장한다 — 사용자가 연 그 학교다
      await ref
          .read(schoolbookSettingsProvider.notifier)
          .connect(info.copyWith(code: code));
      messenger.showSnackBar(
        SnackBar(content: Text(SchoolbookStrings.connected(info.name))),
      );
      widget.onConnected?.call();
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = switch (result.outcome) {
        SbOutcome.unauthorized || SbOutcome.notFound => SchoolbookStrings.connectNotFound,
        SbOutcome.noPeriods => SchoolbookStrings.noPeriods,
        _ => SchoolbookStrings.loadFailed,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: SchoolbookConnectView.fieldKey,
          controller: _field,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _connect(),
          decoration: const InputDecoration(
            labelText: SchoolbookStrings.connectFieldLabel,
            hintText: 'https://schoolbook.zzolab.com/…',
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSizes.spacing8),
          Text(error, style: TextStyle(color: AppColors.inkRed, fontSize: 14)),
        ],
        const SizedBox(height: AppSizes.spacing16),
        Center(
          child: GoldGradientButton(
            key: SchoolbookConnectView.connectKey,
            label: SchoolbookStrings.connectButton,
            enabled: !_busy,
            onPressed: _connect,
          ),
        ),
      ],
    );
  }
}
