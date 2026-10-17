import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/schoolbook/domain/room_order.dart';
import 'package:planroutine/features/schoolbook/domain/schoolbook_models.dart';

const _rooms = [
  SchoolbookRoom(id: 1, name: '강당', capacity: 2),
  SchoolbookRoom(id: 2, name: '과학실', capacity: 2),
  SchoolbookRoom(id: 3, name: '체육관', capacity: 1),
  SchoolbookRoom(id: 4, name: '컴퓨터실', capacity: 1),
];

List<int> _ids(List<SchoolbookRoom> rooms) => [for (final r in rooms) r.id];

void main() {
  test('최근에 들어간 순서가 앞, 나머지는 받은 순서(이름순) 그대로', () {
    expect(_ids(orderByRecent(_rooms, [3, 2])), [3, 2, 1, 4]);
  });

  test('최근 목록이 비면 받은 순서 그대로', () {
    expect(_ids(orderByRecent(_rooms, const [])), [1, 2, 3, 4]);
  });

  test('지워진 교실의 id는 건너뛴다', () {
    expect(_ids(orderByRecent(_rooms, [99, 4])), [4, 1, 2, 3]);
  });

  test('들어간 교실을 맨 앞에 — 중복 없이, 20곳까지', () {
    expect(pushRecent([1, 2, 3], 2), [2, 1, 3]);
    expect(pushRecent([for (var i = 1; i <= 20; i++) i], 99).length, 20);
    expect(pushRecent([for (var i = 1; i <= 20; i++) i], 99).first, 99);
  });
}
