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

    /// 최근에 들어간 교실, 앞이 가장 최근(최대 20곳). 교실 칩이 이 순서로 앞에 선다(사용자 결정).
    @Default(<int>[]) List<int> recentRoomIds,
    String? booker,
  }) = _SchoolbookSettings;

  static const empty = SchoolbookSettings();

  bool get connected => code != null;

  factory SchoolbookSettings.fromJson(Map<String, dynamic> json) {
    T? read<T>(String key) {
      final value = json[key];
      return value is T ? value : null;
    }

    final last = read<int>('lastRoomId');
    final recent = read<List<dynamic>>('recentRoomIds');
    return SchoolbookSettings(
      code: read<String>('code'),
      schoolName: read<String>('schoolName'),
      lastRoomId: last,
      // 최근 목록이 생기기 전의 저장값은 마지막 교실 하나로 시작한다
      recentRoomIds: recent == null
          ? [?last]
          : [for (final id in recent) if (id is int) id],
      booker: read<String>('booker'),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'schoolName': schoolName,
        'lastRoomId': lastRoomId,
        'recentRoomIds': recentRoomIds,
        'booker': booker,
      };
}
