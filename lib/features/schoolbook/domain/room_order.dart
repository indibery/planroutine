import 'schoolbook_models.dart';

/// 최근 목록은 이만큼만 기억한다.
const recentRoomLimit = 20;

/// 최근에 들어간 교실을 앞에, 나머지는 받은 순서(스쿨북의 이름순) 그대로.
List<SchoolbookRoom> orderByRecent(List<SchoolbookRoom> rooms, List<int> recent) {
  final byId = {for (final r in rooms) r.id: r};
  final front = [for (final id in recent) ?byId[id]];
  final seen = {for (final r in front) r.id};
  return [...front, for (final r in rooms) if (!seen.contains(r.id)) r];
}

/// 들어간 교실을 맨 앞으로(중복 없이, [recentRoomLimit]곳까지).
List<int> pushRecent(List<int> recent, int roomId) =>
    [roomId, for (final id in recent) if (id != roomId) id].take(recentRoomLimit).toList();
