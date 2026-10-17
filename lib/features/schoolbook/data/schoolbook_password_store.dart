import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 예약 비밀번호 — **기기 보안 저장소에만** 둔다(iOS Keychain · Android Keystore 암호화).
///
/// 예약 시트가 미리 채우고, 취소 시트는 쓰지 않는다(취소는 매번 묻는다 — 사용자 결정).
/// 숫자 4자리는 다른 곳의 비밀번호와 겹치기 쉬워 prefs(기기 백업에 평문으로 실린다)에 두지 않는다.
/// 키는 저장값이라 배포 뒤 바꾸지 않는다.
class SchoolbookPasswordStore {
  const SchoolbookPasswordStore();

  static const _key = 'schoolbook_password_v1';
  static final _pattern = RegExp(r'^\d{4}$');

  FlutterSecureStorage get _storage => const FlutterSecureStorage();

  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      // 보안 저장소를 못 읽으면(기기 복원 직후 등) 비어 있는 것으로 — 시트에서 다시 입력한다
      return null;
    }
  }

  /// 숫자 4자리만 저장한다. 실패해도 예약 흐름을 막지 않는다(다음에 다시 입력할 뿐이다).
  Future<void> write(String password) async {
    if (!_pattern.hasMatch(password)) return;
    try {
      await _storage.write(key: _key, value: password);
    } catch (_) {}
  }

  Future<void> delete() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
