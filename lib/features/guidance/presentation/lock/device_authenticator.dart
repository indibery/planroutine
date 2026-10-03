import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

enum AuthOutcome { success, failed, noCredentials }

/// 기기 인증 한 번. 테스트에서 바꿔 끼우려고 인터페이스로 둔다.
abstract class DeviceAuthenticator {
  Future<AuthOutcome> authenticate(String reason);
}

/// Face ID·지문, 없으면 기기 암호(`biometricOnly: false`).
class LocalDeviceAuthenticator implements DeviceAuthenticator {
  LocalDeviceAuthenticator([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    try {
      // 암호조차 없는 기기는 지원하지 않는 것으로 나온다.
      if (!await _auth.isDeviceSupported()) return AuthOutcome.noCredentials;
      final ok = await _auth.authenticate(localizedReason: reason);
      return ok ? AuthOutcome.success : AuthOutcome.failed;
    } on LocalAuthException catch (e) {
      return e.code == LocalAuthExceptionCode.noCredentialsSet
          ? AuthOutcome.noCredentials
          : AuthOutcome.failed;
    } on PlatformException {
      return AuthOutcome.failed;
    }
  }
}

final deviceAuthenticatorProvider = Provider<DeviceAuthenticator>(
  (ref) => LocalDeviceAuthenticator(),
);
