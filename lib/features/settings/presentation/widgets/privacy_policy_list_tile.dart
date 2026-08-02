import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

/// 인앱 개인정보처리방침 링크 — 탭이 있는 행이라 [AppInfoListTile]·
/// [DataSourceListTile]의 `Column`에 **넣지 않는다**(settings_screen.dart 참고).
/// 그 블록은 "둘 다 정보성이고 탭이 없다"는 성격이라, 탭 가능한 행을 섞으면
/// 어디를 누를 수 있는지가 흐려진다. 별 `SettingsSection`으로 앱 정보 위에 둔다.
///
/// **Play User Data 정책이 요구하는 항목이다** — "a privacy policy link or text
/// within the app itself". Play Console의 지정 필드는 이미 채웠고, 이 행이
/// 앱 안의 표시를 맡는다.
///
/// [onOpen]을 주입 가능하게 둔 이유: `url_launcher`의 `launchUrl`은 위젯
/// 테스트에서 실호출할 수 없다. 주입이 없으면 이 행은 테스트 0건이 된다.
/// 기본값은 실제 `launchUrl` 호출이고, 실패(반환값 false 또는 예외)는
/// 예외로 통일해 던진다 — 이 위젯은 예외 여부만으로 성공/실패를 가른다.
///
/// ⚠️ `canLaunchUrl`은 쓰지 않는다 — `Info.plist`의
/// `LSApplicationQueriesSchemes`/Android `<queries>`는 **조회(`canLaunchUrl`)에만**
/// 걸리는 요건이고 `launchUrl` 실행 자체에는 필요 없다(url_launcher 6.3.2 README).
class PrivacyPolicyListTile extends StatelessWidget {
  const PrivacyPolicyListTile({super.key, this.onOpen = _defaultOpen});

  final Future<void> Function(String url) onOpen;

  static Future<void> _defaultOpen(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw Exception('launchUrl returned false: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.privacy_tip_outlined, color: AppColors.textSecondary),
      title: const Text(SettingsStrings.privacyPolicyTitle),
      onTap: () => _onTap(context),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    try {
      await onOpen(SettingsStrings.privacyPolicyUrl);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text(SettingsStrings.privacyPolicyFailed)),
        );
    }
  }
}
