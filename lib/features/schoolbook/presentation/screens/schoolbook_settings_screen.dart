import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/schoolbook_providers.dart';
import '../widgets/schoolbook_connect_view.dart';

/// 장소 예약 상세 설정(`기능 관리 › 장소 예약 › 상세 설정`, 탭의 ⚙).
/// 켜고 끄는 스위치는 없다 — 기능 행에 하나뿐이다(설정 규칙). 확인 창도 없다.
class SchoolbookSettingsScreen extends ConsumerStatefulWidget {
  const SchoolbookSettingsScreen({super.key});

  static const bookerKey = Key('schoolbook_settings_booker');
  static const saveBookerKey = Key('schoolbook_settings_save_booker');
  static const passwordKey = Key('schoolbook_settings_password');
  static const savePasswordKey = Key('schoolbook_settings_save_password');
  static const clearPasswordKey = Key('schoolbook_settings_clear_password');
  static const disconnectKey = Key('schoolbook_settings_disconnect');

  @override
  ConsumerState<SchoolbookSettingsScreen> createState() => _SchoolbookSettingsScreenState();
}

class _SchoolbookSettingsScreenState extends ConsumerState<SchoolbookSettingsScreen> {
  final _booker = TextEditingController();
  final _password = TextEditingController();
  bool _changingLink = false;
  bool _hasPassword = false;
  bool _bookerFilled = false;

  @override
  void initState() {
    super.initState();
    _loadPassword();
  }

  @override
  void dispose() {
    _booker.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadPassword() async {
    final saved = await ref.read(schoolbookPasswordStoreProvider).read();
    if (mounted) setState(() => _hasPassword = saved != null);
  }

  Future<void> _savePassword() async {
    await ref.read(schoolbookPasswordStoreProvider).write(_password.text);
    _password.clear();
    await _loadPassword();
  }

  Future<void> _clearPassword() async {
    await ref.read(schoolbookPasswordStoreProvider).delete();
    await _loadPassword();
  }

  Future<void> _disconnect() async {
    await ref.read(schoolbookSettingsProvider.notifier).disconnect();
    _bookerFilled = false;
    await _loadPassword();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(schoolbookSettingsProvider).valueOrNull;
    if (settings != null && !_bookerFilled) {
      // 저장값이 처음 도착했을 때 한 번만 채운다 — 입력 중인 글을 덮지 않는다
      _booker.text = settings.booker ?? '';
      _bookerFilled = true;
    }
    final connected = settings?.connected ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(SchoolbookStrings.title, style: AppTextStyles.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
        children: [
          if (!connected || _changingLink)
            Padding(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: SchoolbookConnectView(
                onConnected: () => setState(() => _changingLink = false),
              ),
            ),
          if (connected) ...[
            ListTile(
              title: const Text(SchoolbookStrings.settingsSchool),
              trailing: Text(settings?.schoolName ?? ''),
            ),
            if (!_changingLink)
              ListTile(
                title: const Text(SchoolbookStrings.changeLink),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _changingLink = true),
              ),
            const Divider(),
            _fieldRow(
              field: TextField(
                key: SchoolbookSettingsScreen.bookerKey,
                controller: _booker,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: SchoolbookStrings.defaultBookerLabel,
                  helperText: SchoolbookStrings.defaultBookerHint,
                ),
              ),
              button: TextButton(
                key: SchoolbookSettingsScreen.saveBookerKey,
                onPressed: () =>
                    ref.read(schoolbookSettingsProvider.notifier).setBooker(_booker.text),
                child: const Text(SchoolbookStrings.saveBooker),
              ),
            ),
            _fieldRow(
              field: TextField(
                key: SchoolbookSettingsScreen.passwordKey,
                controller: _password,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: SchoolbookStrings.passwordFieldLabel,
                  helperText: _hasPassword
                      ? SchoolbookStrings.passwordSaved
                      : SchoolbookStrings.passwordFieldHint,
                ),
              ),
              button: TextButton(
                key: SchoolbookSettingsScreen.savePasswordKey,
                onPressed: _password.text.length == 4 ? _savePassword : null,
                child: const Text(SchoolbookStrings.savePassword),
              ),
            ),
            if (_hasPassword)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSizes.spacing8),
                  child: TextButton(
                    key: SchoolbookSettingsScreen.clearPasswordKey,
                    onPressed: _clearPassword,
                    child: const Text(SchoolbookStrings.clearPassword),
                  ),
                ),
              ),
            const Divider(),
            ListTile(
              key: SchoolbookSettingsScreen.disconnectKey,
              title: Text(
                SchoolbookStrings.disconnect,
                style: TextStyle(color: AppColors.inkRed),
              ),
              subtitle: const Text(SchoolbookStrings.disconnectNote),
              onTap: _disconnect,
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldRow({required Widget field, required Widget button}) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.spacing16, AppSizes.spacing8, AppSizes.spacing8, 0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field),
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.spacing8),
              child: button,
            ),
          ],
        ),
      );
}
