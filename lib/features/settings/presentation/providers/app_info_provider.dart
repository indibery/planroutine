import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 앱 버전/빌드 정보 스냅샷
class AppInfo {
  const AppInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String version;
  final String buildNumber;

  /// UI 표시용: "v1.0.0 (16)"
  String get displayVersion => 'v$version ($buildNumber)';
}

/// 앱 정보 프로바이더 (1회 조회 후 캐시)
final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppInfo(
    appName: info.appName,
    version: info.version,
    buildNumber: info.buildNumber,
  );
});
