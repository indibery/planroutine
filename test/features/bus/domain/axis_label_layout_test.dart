import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/axis_label_layout.dart';

const _w = 34.0; // BusBodyAxis.labelWidth
const _axis = 300.0;

void main() {
  group('layoutAxisLabels — 겹치면 밀어낸다', () {
    test('멀리 떨어진 라벨은 건드리지 않는다', () {
      final out = layoutAxisLabels([50, 150, 250], _w, _axis);
      expect(out, [50, 150, 250]);
    });

    test('붙어 있으면 최소 간격만큼 벌린다', () {
      // 실기기 신고 2026-07-30: 1분·1.5분 두 대의 라벨이 겹쳐 `55536023`으로 읽혔다.
      final out = layoutAxisLabels([20, 30], _w, _axis);

      expect(out[0], 20, reason: '첫 라벨은 제자리');
      expect(out[1] - out[0], greaterThanOrEqualTo(_w));
    });

    test('셋이 붙어도 차례로 벌어진다', () {
      final out = layoutAxisLabels([20, 25, 30], _w, _axis);
      for (var i = 1; i < out.length; i++) {
        expect(out[i] - out[i - 1], greaterThanOrEqualTo(_w - 0.01));
      }
    });

    test('오른쪽 끝을 넘기면 반대로 되민다', () {
      // 축 끝에 몰린 경우. 밀기만 하면 마지막 라벨이 화면 밖으로 나간다.
      final out = layoutAxisLabels([280, 285, 290], _w, _axis);

      expect(out.last, lessThanOrEqualTo(_axis - _w / 2 + 0.01));
      expect(out.first, greaterThanOrEqualTo(_w / 2 - 0.01));
      for (var i = 1; i < out.length; i++) {
        expect(out[i] - out[i - 1], greaterThanOrEqualTo(_w - 0.01));
      }
    });

    test('양 끝을 벗어나지 않는다', () {
      final out = layoutAxisLabels([0, 300], _w, _axis);
      expect(out.first, greaterThanOrEqualTo(_w / 2 - 0.01));
      expect(out.last, lessThanOrEqualTo(_axis - _w / 2 + 0.01));
    });

    test('폭이 모자라면 고르게 편다 — 겹침을 줄이되 밖으로 내보내지 않는다', () {
      // 노선을 많이 걸면 상한이 풀려 여덟 대가 보일 수 있다.
      // 8 × 34 = 272pt로 축(300pt)에 간신히 들어가지 않는 구간을 만든다.
      final out = layoutAxisLabels(List.filled(12, 150), _w, _axis);

      expect(out.length, 12);
      expect(out.first, greaterThanOrEqualTo(_w / 2 - 0.01));
      expect(out.last, lessThanOrEqualTo(_axis - _w / 2 + 0.01));
      for (var i = 1; i < out.length; i++) {
        expect(
          out[i],
          greaterThanOrEqualTo(out[i - 1]),
          reason: '순서가 뒤집히면 라벨과 점의 대응이 무너진다',
        );
      }
    });

    test('빈 목록과 한 개는 그대로', () {
      expect(layoutAxisLabels([], _w, _axis), isEmpty);
      expect(layoutAxisLabels([120], _w, _axis), [120]);
    });

    test('순서는 절대 뒤집히지 않는다', () {
      // 밀어내기가 순서를 바꾸면 라벨이 남의 점 위에 선다.
      for (final input in [
        [10.0, 12.0, 14.0, 200.0],
        [100.0, 101.0],
        [5.0, 295.0],
      ]) {
        final out = layoutAxisLabels(input, _w, _axis);
        for (var i = 1; i < out.length; i++) {
          expect(out[i], greaterThanOrEqualTo(out[i - 1] - 0.01));
        }
      }
    });
  });

  group('assignLabelRows — 버스가 한 번 받은 줄을 지킨다', () {
    const w = 58.0;

    test('처음에는 붙어 있는 이웃끼리 줄을 번갈아 쓴다', () {
      final rows = assignLabelRows(
        [('A', 20), ('B', 40), ('C', 60)],
        const {},
        w,
      );
      expect(rows, {'A': 0, 'B': 1, 'C': 0});
    });

    test('맨 앞 버스가 지나가도 남은 라벨은 줄을 바꾸지 않는다', () {
      // 짝·홀 순서로 줄을 정하던 판본은 여기서 B·C가 함께 뒤집혀 1초 동안 위아래로
      // 미끄러졌다(2026-10-09 점검). 점이 차량 키로 정체성을 잇는 것과 같은 이유다.
      final rows = assignLabelRows(
        [('B', 40), ('C', 60)],
        const {'A': 0, 'B': 1, 'C': 0},
        w,
      );
      expect(rows, {'B': 1, 'C': 0});
    });

    test('새로 들어온 버스는 왼쪽 이웃과 다른 줄로 간다', () {
      final rows = assignLabelRows(
        [('B', 40), ('C', 60), ('D', 80)],
        const {'B': 1, 'C': 0},
        w,
      );
      expect(rows['D'], 1);
    });

    test('기억한 줄이 붙어 있는 이웃과 같으면 그때만 바꾼다', () {
      final rows = assignLabelRows(
        [('A', 20), ('B', 40)],
        const {'A': 0, 'B': 0},
        w,
      );
      expect(rows, {'A': 0, 'B': 1});
    });

    test('멀리 떨어져 있으면 같은 줄이어도 그대로 둔다', () {
      final rows = assignLabelRows(
        [('A', 20), ('B', 200)],
        const {'A': 0, 'B': 0},
        w,
      );
      expect(rows, {'A': 0, 'B': 0});
    });
  });
}
