import 'package:freezed_annotation/freezed_annotation.dart';

part 'schoolbook_settings.freezed.dart';

/// 장소 예약 기능의 기기 저장값(`schoolbook_settings_v1`).
///
/// **비밀번호 칸은 없다** — 예약 비밀번호는 보안 저장소(`SchoolbookPasswordStore`)에 따로 둔다.
/// 키 이름은 저장값이라 배포 뒤 바꾸지 않는다.
@freezed
abstract class SchoolbookSettings with _$SchoolbookSettings {
  const SchoolbookSettings._();

  const factory SchoolbookSettings({
    String? code,
    String? schoolName,
    int? lastRoomId,
    String? booker,
  }) = _SchoolbookSettings;

  static const empty = SchoolbookSettings();

  bool get connected => code != null;

  factory SchoolbookSettings.fromJson(Map<String, dynamic> json) {
    T? read<T>(String key) {
      final value = json[key];
      return value is T ? value : null;
    }

    return SchoolbookSettings(
      code: read<String>('code'),
      schoolName: read<String>('schoolName'),
      lastRoomId: read<int>('lastRoomId'),
      booker: read<String>('booker'),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'schoolName': schoolName,
        'lastRoomId': lastRoomId,
        'booker': booker,
      };
}
