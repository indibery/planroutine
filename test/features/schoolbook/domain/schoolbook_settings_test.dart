import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/schoolbook/domain/schoolbook_settings.dart';

void main() {
  const full = SchoolbookSettings(
    code: 'abcdefghijk12',
    schoolName: '플랜테스트',
    lastRoomId: 12,
    booker: '체육전담',
  );

  test('저장 키는 넷뿐이다', () {
    expect(full.toJson().keys.toSet(),
        {'code', 'schoolName', 'lastRoomId', 'booker'});
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
