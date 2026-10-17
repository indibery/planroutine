import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/sb_result.dart';
import '../../data/schoolbook_api_client.dart';
import '../../data/schoolbook_password_store.dart';
import '../../domain/schoolbook_models.dart';
import '../../domain/schoolbook_settings.dart';

/// 장소 예약 설정 저장 키. **저장값이라 바꾸지 않는다.**
const schoolbookSettingsPrefsKey = 'schoolbook_settings_v1';

final schoolbookApiClientProvider =
    Provider<SchoolbookApiClient>((ref) => SchoolbookApiClient());

/// 예약 비밀번호 보안 저장소. 설정 JSON과 따로 둔다.
final schoolbookPasswordStoreProvider =
    Provider<SchoolbookPasswordStore>((ref) => const SchoolbookPasswordStore());

/// 학교 연결 · 마지막 교실 · 예약자 이름. 비밀번호는 여기 없다 — [schoolbookPasswordStoreProvider].
final schoolbookSettingsProvider =
    AsyncNotifierProvider<SchoolbookSettingsNotifier, SchoolbookSettings>(
      SchoolbookSettingsNotifier.new,
    );

class SchoolbookSettingsNotifier extends AsyncNotifier<SchoolbookSettings> {
  @override
  Future<SchoolbookSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(schoolbookSettingsPrefsKey);
    if (raw == null) {
      // iOS Keychain은 앱을 지워도 남는다. 비밀번호는 연결 뒤에만 생기므로, 설정 없이 남은
      // 비밀번호는 지운 설치의 것이다 — 다시 설치한 사람에게 채워 주지 않는다(처리방침 §7)
      // 기다리지 않는다 — 보안 저장소가 늦어도 화면이 붙잡히지 않게
      unawaited(ref.read(schoolbookPasswordStoreProvider).delete());
      return SchoolbookSettings.empty;
    }
    try {
      return SchoolbookSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 손상된 값이면 연결 전으로
      return SchoolbookSettings.empty;
    }
  }

  SchoolbookSettings get _current => state.valueOrNull ?? SchoolbookSettings.empty;

  /// 학교를 (다시) 연결한다. 다른 학교일 수 있으니 마지막 교실은 비운다.
  Future<void> connect(SchoolInfo info) => _save(
        _current.copyWith(code: info.code, schoolName: info.name, lastRoomId: null),
      );

  /// 앱의 저장값(예약 비밀번호 포함)만 지운다. 스쿨북의 예약은 그대로다.
  Future<void> disconnect() async {
    state = const AsyncData(SchoolbookSettings.empty);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(schoolbookSettingsPrefsKey);
    await ref.read(schoolbookPasswordStoreProvider).delete();
  }

  Future<void> setLastRoom(int roomId) => _save(_current.copyWith(lastRoomId: roomId));

  Future<void> setBooker(String booker) {
    final trimmed = booker.trim();
    return _save(_current.copyWith(booker: trimmed.isEmpty ? null : trimmed));
  }

  Future<void> _save(SchoolbookSettings next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(schoolbookSettingsPrefsKey, jsonEncode(next.toJson()));
  }
}

/// 연결된 학교의 교실 목록. 캐시하지 않는다 — 화면이 열릴 때마다 새로 부른다.
final schoolbookRoomsProvider =
    FutureProvider.autoDispose<SbResult<List<SchoolbookRoom>>>((ref) async {
  final code = await ref.watch(schoolbookSettingsProvider.selectAsync((s) => s.code));
  if (code == null) return const SbResult(SbOutcome.unauthorized);
  return ref.read(schoolbookApiClientProvider).rooms(code);
});

typedef RoomDayKey = ({int roomId, DateTime date});

/// 교실 하나의 하루. 남이 방금 잡은 자리를 보여 줘야 해서 캐시하지 않는다 —
/// 다시 부르려면 `ref.invalidate(roomDayProvider(key))`.
final roomDayProvider =
    FutureProvider.autoDispose.family<SbResult<RoomDay>, RoomDayKey>((ref, key) async {
  final code = await ref.watch(schoolbookSettingsProvider.selectAsync((s) => s.code));
  if (code == null) return const SbResult(SbOutcome.unauthorized);
  return ref.read(schoolbookApiClientProvider).roomDay(code, key.roomId, key.date);
});
