// 기기 캘린더 저장은 **계정 캘린더를 로컬보다 먼저** 고른다.
//
// 실기기에서 저장이 삼성의 로컬 `My calendar`로 갔다(Galaxy A34, 2026-08-06).
// 그 캘린더는 동기화되지 않아 PC에서 안 보이고 기기를 바꾸면 사라진다 —
// "캘린더로 보낸다"고 할 때 기대하는 것과 정반대다.
//
// **`isDefault`만으로는 못 고른다**: 그 기기는 캘린더 여섯 개가 **전부**
// `isPrimary=1`로 왔다. 값이 아무것도 구분해주지 못하니 판정이 커서 순서
// 첫 번째로 떨어졌고 그게 로컬이었다.
//
// 아래 픽스처는 그 기기에서 실제로 읽은 목록이다(계정 이름만 가림).

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/device_calendar/domain/default_calendar.dart';

Calendar _cal({
  required String id,
  required String name,
  required String accountType,
  bool readOnly = false,
  bool isDefault = true,
}) {
  return Calendar(
    id: id,
    name: name,
    accountName: name,
    accountType: accountType,
    isReadOnly: readOnly,
    isDefault: isDefault,
  );
}

/// Galaxy A34 실측 구성 — 전부 `isDefault=true`인 것이 핵심이다.
final _galaxyA34 = [
  _cal(id: '1', name: 'My calendar', accountType: 'LOCAL'),
  _cal(id: '2', name: '연락처에 저장된 중요한 날', accountType: 'LOCAL', readOnly: true),
  _cal(id: '3', name: '공휴일', accountType: 'LOCAL', readOnly: true),
  _cal(id: '4', name: '법정기념일', accountType: 'LOCAL', readOnly: true),
  _cal(id: '5', name: '절기와 세시풍속', accountType: 'LOCAL', readOnly: true),
  _cal(id: '11', name: 'teacher@example.com', accountType: 'com.google'),
];

void main() {
  group('저장할 캘린더 고르기', () {
    test('실기기 구성 — 로컬이 먼저 와도 구글 계정 캘린더를 고른다', () {
      final chosen = pickDefaultCalendar(_galaxyA34);
      expect(chosen?.id, '11',
          reason: '로컬 My calendar(id=1)가 목록 앞에 있고 isDefault도 true지만, '
              '계정 캘린더가 있으면 그쪽이 정답이다');
    });

    test('계정 캘린더가 없으면 로컬을 쓴다 — 금지가 아니라 후순위다', () {
      final localOnly =
          _galaxyA34.where((c) => c.accountType == 'LOCAL').toList();
      expect(pickDefaultCalendar(localOnly)?.id, '1',
          reason: '쓰기 가능한 것이 로컬뿐이면 그것이 유일한 선택지다');
    });

    test('iOS는 accountType이 "Local" — 대소문자가 달라도 같게 본다', () {
      final ios = [
        _cal(id: 'l1', name: '기본', accountType: 'Local'),
        _cal(id: 'c1', name: 'iCloud', accountType: 'CalDAV'),
      ];
      expect(pickDefaultCalendar(ios)?.id, 'c1',
          reason: 'iOS(EventKit)는 "Local", Android는 "LOCAL"로 온다');
    });

    test('읽기 전용은 후보에서 빠진다', () {
      final readOnlyGoogle = [
        _cal(id: '1', name: 'My calendar', accountType: 'LOCAL'),
        _cal(id: '9', name: '대한민국의 휴일', accountType: 'com.google', readOnly: true),
      ];
      expect(pickDefaultCalendar(readOnlyGoogle)?.id, '1',
          reason: '계정 캘린더라도 읽기 전용이면 저장할 수 없다');
    });

    test('계정 캘린더가 여럿이면 isDefault를 본다', () {
      final two = [
        _cal(id: 'a', name: '학교', accountType: 'com.google', isDefault: false),
        _cal(id: 'b', name: '개인', accountType: 'com.google', isDefault: true),
      ];
      expect(pickDefaultCalendar(two)?.id, 'b');
    });

    test('쓸 수 있는 것이 하나도 없으면 null', () {
      final none = [
        _cal(id: '3', name: '공휴일', accountType: 'LOCAL', readOnly: true),
      ];
      expect(pickDefaultCalendar(none), isNull,
          reason: 'null이면 호출부가 "쓸 수 있는 캘린더가 없다"로 처리한다');
    });
  });
}
