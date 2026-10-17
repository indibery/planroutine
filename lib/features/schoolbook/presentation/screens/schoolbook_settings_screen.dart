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
  static const revealPasswordKey = Key('schoolbook_settings_reveal_password');
  static const disconnectKey = Key('schoolbook_settings_disconnect');

  @override
  ConsumerState<SchoolbookSettingsScreen> createState() => _SchoolbookSettingsScreenState();
}

class _SchoolbookSettingsScreenState extends ConsumerState<SchoolbookSettingsScreen> {
  final _booker = TextEditingController();
  final _password = TextEditingController();
  bool _changingLink = false;
  /// 저장한 비밀번호. 화면에 숫자로 보이는 것은 [보기]를 누른 동안뿐이다 —
  /// 바로 예약은 비밀번호를 보여 주지 않아, 취소할 때 잊었으면 여기서 확인한다(사용자 결정).
  String? _savedPassword;
  bool _revealed = false;
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
    if (mounted) {
      setState(() {
        _savedPassword = saved;
        _revealed = false;
      });
    }
  }

  Future<void> _saveBooker() async {
    await ref.read(schoolbookSettingsProvider.notifier).setBooker(_booker.text);
    final saved = ref.read(schoolbookSettingsProvider).valueOrNull?.booker ?? '';
    _booker.text = saved; // 앞뒤 공백을 정리한 저장값을 그대로 보인다
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(SchoolbookStrings.bookerSaved)),
    );
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
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: SchoolbookStrings.defaultBookerLabel,
                  helperText: SchoolbookStrings.defaultBookerHint,
                  helperMaxLines: 2, // 한 줄이면 '같은 이…'로 잘렸다(시뮬레이터)
                ),
              ),
              button: TextButton(
                key: SchoolbookSettingsScreen.saveBookerKey,
                // 저장값과 다를 때만 켠다 — 늘 켜져 있으면 저장됐는지 알 수 없었다(실기기 피드백)
                onPressed:
                    _booker.text.trim() != (settings?.booker ?? '') ? _saveBooker : null,
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
                  helperText: _savedPassword != null
                      ? SchoolbookStrings.passwordSaved
                      : SchoolbookStrings.passwordFieldHint,
                  helperMaxLines: 2,
                ),
              ),
              button: TextButton(
                key: SchoolbookSettingsScreen.savePasswordKey,
                onPressed: _password.text.length == 4 ? _savePassword : null,
                child: const Text(SchoolbookStrings.savePassword),
              ),
            ),
            if (_savedPassword case final saved?)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.spacing16, 0, AppSizes.spacing8, 0,
                ),
                child: Row(
                  children: [
                    Text(
                      SchoolbookStrings.savedPasswordLabel,
                      style: TextStyle(fontSize: 14, color: AppColors.sub),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    Text(
                      _revealed ? saved : '••••',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: 2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      key: SchoolbookSettingsScreen.revealPasswordKey,
                      onPressed: () => setState(() => _revealed = !_revealed),
                      child: Text(
                        _revealed ? SchoolbookStrings.hidePassword : SchoolbookStrings.revealPassword,
                      ),
                    ),
                  ],
                ),
              ),
            if (_savedPassword != null)
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
