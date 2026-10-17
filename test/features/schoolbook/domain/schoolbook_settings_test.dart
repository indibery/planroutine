import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/schoolbook/domain/schoolbook_settings.dart';

void main() {
  const full = SchoolbookSettings(
    code: 'abcdefghijk12',
    schoolName: '플랜테스트',
    lastRoomId: 12,
    recentRoomIds: [12, 7],
    booker: '체육전담',
  );

  test('저장 키는 다섯뿐이다', () {
    expect(full.toJson().keys.toSet(),
        {'code', 'schoolName', 'lastRoomId', 'recentRoomIds', 'booker'});
  });

  test('최근 들어간 장소 목록을 되읽는다', () {
    const s = SchoolbookSettings(recentRoomIds: [3, 1, 2]);
    expect(SchoolbookSettings.fromJson(s.toJson()).recentRoomIds, [3, 1, 2]);
  });

  test('최근 목록이 없던 저장값은 마지막 교실 하나로 시작한다', () {
    expect(SchoolbookSettings.fromJson({'lastRoomId': 12}).recentRoomIds, [12]);
  });

  test('최근 목록에 숫자가 아닌 값이 섞이면 버린다', () {
    expect(
      SchoolbookSettings.fromJson({'recentRoomIds': [3, 'x', 1.5, 2]}).recentRoomIds,
      [3, 2],
    );
  });

  test('되읽으면 같다', () {
    expect(SchoolbookSettings.fromJson(full.toJson()), full);
  });

  test('비밀번호 칸은 어떤 입력에도 없다', () {
    final json = SchoolbookSettings.fromJson({...full.toJson(), 'password': '1234'})
        .toJson();
    expect(json.containsKey('password'), isFalse);
    expect(json.values, isNot(contains('1234')));
  });

  test('형이 틀린 칸은 null', () {
    expect(SchoolbookSettings.fromJson({'lastRoomId': 'x'}).lastRoomId, isNull);
  });

  test('코드가 있어야 연결된 것이다', () {
    expect(SchoolbookSettings.empty.connected, isFalse);
    expect(full.connected, isTrue);
  });
}
