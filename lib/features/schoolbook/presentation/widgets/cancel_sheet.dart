import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
import '../../../../shared/widgets/sheet_title.dart';
import '../../data/sb_result.dart';
import 'book_sheet.dart';

/// `unknown` = 응답을 못 받아 결과를 모른다.
enum CancelSheetResult { canceled, unknown }

typedef CancelSubmit = Future<SbResult<void>> Function(String password);

/// 취소 시트. **저장한 비밀번호를 채우지 않는다** — 취소는 매번 묻는다(사용자 결정).
Future<CancelSheetResult?> showCancelSheet(
  BuildContext context, {
  required String booker,
  required String periodName,
  required CancelSubmit submit,
}) {
  return showModalBottomSheet<CancelSheetResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => CancelSheet(booker: booker, periodName: periodName, submit: submit),
  );
}

class CancelSheet extends StatefulWidget {
  const CancelSheet({
    super.key,
    required this.booker,
    required this.periodName,
    required this.submit,
  });

  final String booker;
  final String periodName;
  final CancelSubmit submit;

  static const passwordKey = Key('schoolbook_cancel_password');
  static const submitKey = Key('schoolbook_cancel_submit');

  @override
  State<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<CancelSheet> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _valid => RegExp(r'^\d{4}$').hasMatch(_password.text);

  Future<void> _send() async {
    if (_busy || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.submit(_password.text);
    if (!mounted) return;
    switch (result.outcome) {
      case SbOutcome.ok:
        Navigator.of(context).pop(CancelSheetResult.canceled);
      case SbOutcome.network:
        Navigator.of(context).pop(CancelSheetResult.unknown);
      case SbOutcome.notFound:
        setState(() {
          _busy = false;
          _error = SchoolbookStrings.alreadyCanceled;
        });
      case SbOutcome.rejected || SbOutcome.unauthorized || SbOutcome.noPeriods:
        setState(() {
          _busy = false;
          _error = result.detail ?? SchoolbookStrings.loadFailed;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Padding(
      padding: EdgeInsets.only(bottom: math.max(0, MediaQuery.viewInsetsOf(context).bottom)),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle(SchoolbookStrings.cancelSheetTitle(widget.booker, widget.periodName)),
              const SizedBox(height: AppSizes.spacing16),
              SheetPasswordField(
                fieldKey: CancelSheet.passwordKey,
                controller: _password,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _send(),
              ),
              if (error != null) SheetError(error),
              const SizedBox(height: AppSizes.spacing16),
              Center(
                child: GoldGradientButton(
                  key: CancelSheet.submitKey,
                  label: SchoolbookStrings.cancelBooking,
                  enabled: _valid && !_busy,
                  onPressed: _send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
