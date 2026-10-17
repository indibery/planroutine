import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
import '../../../../shared/widgets/sheet_title.dart';
import '../../data/sb_result.dart';

/// 시트가 닫힌 이유. `unknown` = 응답을 못 받아 결과를 모른다(서버엔 반영됐을 수 있다).
enum BookSheetResult { booked, unknown }

typedef BookSubmit =
    Future<SbResult<void>> Function(String booker, String password);

/// 예약 시트. 예약자와 저장한 비밀번호가 미리 채워져 있어 대개 `예약`만 누른다.
/// 확인 창은 없다 — 이 버튼이 확인이다.
Future<BookSheetResult?> showBookSheet(
  BuildContext context, {
  required String title,
  required String? initialBooker,
  required String? initialPassword,
  required BookSubmit submit,
}) {
  return showModalBottomSheet<BookSheetResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    // 끌어서 닫기는 PopScope를 거치지 않는다 — 요청 중에 닫히면 결과가 조용히 사라진다
    enableDrag: false,
    builder: (_) => BookSheet(
      title: title,
      initialBooker: initialBooker,
      initialPassword: initialPassword,
      submit: submit,
    ),
  );
}

final _passwordPattern = RegExp(r'^\d{4}$');

class BookSheet extends StatefulWidget {
  const BookSheet({
    super.key,
    required this.title,
    required this.initialBooker,
    required this.initialPassword,
    required this.submit,
  });

  final String title;
  final String? initialBooker;
  final String? initialPassword;
  final BookSubmit submit;

  static const bookerKey = Key('schoolbook_book_booker');
  static const passwordKey = Key('schoolbook_book_password');
  static const submitKey = Key('schoolbook_book_submit');

  @override
  State<BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<BookSheet> {
  late final _booker = TextEditingController(text: widget.initialBooker ?? '');
  late final _password = TextEditingController(
    text: widget.initialPassword ?? '',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _booker.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid {
    final booker = _booker.text.trim();
    return booker.isNotEmpty &&
        booker.length <= 20 &&
        _passwordPattern.hasMatch(_password.text);
  }

  Future<void> _send() async {
    if (_busy || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.submit(_booker.text.trim(), _password.text);
    if (!mounted) return;
    switch (result.outcome) {
      case SbOutcome.ok:
        Navigator.of(context).pop(BookSheetResult.booked);
      case SbOutcome.network:
        Navigator.of(context).pop(BookSheetResult.unknown);
      case SbOutcome.rejected ||
          SbOutcome.notFound ||
          SbOutcome.unauthorized ||
          SbOutcome.noPeriods:
        setState(() {
          _busy = false;
          _error = result.detail ?? SchoolbookStrings.loadFailed;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    // 요청 중에는 닫지 않는다(바깥 누르기 · 뒤로 가기). 닫히면 성공해도 목록·알림이 갱신되지 않아
    // 다시 누르게 되고, 정원 2 이상인 교실에서는 같은 반이 두 번 예약된다
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: math.max(0, MediaQuery.viewInsetsOf(context).bottom),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetTitle(widget.title),
                const SizedBox(height: AppSizes.spacing16),
                TextField(
                  key: BookSheet.bookerKey,
                  controller: _booker,
                  maxLength: 20,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: SchoolbookStrings.bookerLabel,
                    hintText: SchoolbookStrings.bookerHint,
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                SheetPasswordField(
                  fieldKey: BookSheet.passwordKey,
                  controller: _password,
                  autofocus: widget.initialPassword == null,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(),
                ),
                if (error != null) SheetError(error),
                const SizedBox(height: AppSizes.spacing16),
                Center(
                  child: GoldGradientButton(
                    key: BookSheet.submitKey,
                    label: SchoolbookStrings.book,
                    enabled: _valid && !_busy,
                    onPressed: _send,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 숫자 4자리 비밀번호 칸(가림). 예약·취소 시트가 함께 쓴다.
class SheetPasswordField extends StatelessWidget {
  const SheetPasswordField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.autofocus,
    required this.onChanged,
    required this.onSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    autofocus: autofocus,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 4,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    decoration: const InputDecoration(
      labelText: SchoolbookStrings.passwordLabel,
    ),
  );
}

/// 시트 안 오류 한 줄(서버 문구를 그대로).
class SheetError extends StatelessWidget {
  const SheetError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSizes.spacing8),
    child: Text(text, style: TextStyle(color: AppColors.inkRed, fontSize: 14)),
  );
}
