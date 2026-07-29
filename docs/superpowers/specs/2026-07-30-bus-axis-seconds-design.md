# 버스 시간 축 — 초 보존 + 스르르 이동

- 날짜: 2026-07-30
- 상태: 승인됨
- 범위: 버스 카드 도메인·파서·시간 축 위젯. 새 API·새 화면 없음.

## 문제

실기기 신고(2026-07-30): 시간 축의 버스가 **뚝뚝 뛰고**, 눈금이 5분 단위라 **몇 분인지
가늠이 거칠다.**

두 증상의 뿌리가 하나다 — **초를 받아 놓고 버린다.**

| 지점 | 지금 | 결과 |
|---|---|---|
| `tago_response_parser.dart:148` | `arrMin = ceil(arrtime / 60)` | 초 소실 |
| `gbis_response_parser.dart:_arrMin` | `ceil(predictTimeSec1 / 60)` | 초 소실 |
| `bus_card_view.dart:99` | `round((arrMin*60 − elapsed) / 60)` | 다시 분으로 양자화 |
| `bus_body_axis.dart:51` | `arrMin / 15` | 점이 분 격자에만 선다 |
| `bus_card_host.dart` | 30초 폴링 시에만 리빌드 | 30초마다 순간이동 |

즉 `predictTimeSec1: 361`(6분 1초)과 `359`(5분 59초)가 같은 자리에 서고, 그 자리에
30초를 머물다 한 칸 튄다.

## 설계

### 1. `BusArrival`이 초를 든다

```dart
class BusArrival {
  const BusArrival({required this.arrSec, ...});

  /// 도착까지 남은 **초**. 진실의 원천.
  final int arrSec;

  /// 표시·정렬용 분. 화면 문구와 스크린리더가 쓴다.
  int get arrMin => (arrSec / 60).round();

  /// 분만 아는 경로(GBIS `predictTime1` 폴백, 테스트 픽스처)용.
  factory BusArrival.fromMinutes({required int arrMin, ...}) =>
      BusArrival(arrSec: arrMin * 60, ...);

  BusArrival copyWith({int? arrSec});
}
```

**`arrMin`을 파생 getter로 남기는 것이 핵심이다.** `bus_body_text`·정렬·상한·
스크린리더 라벨·`toString`이 그대로 돌아가고, `arrMin`을 읽는 테스트도 무수정이다.
바꿀 곳은 **생성자를 호출하는 자리**뿐이다.

### 2. 파서는 초를 그대로 넘긴다

`ceil`을 지운다. GBIS는 초가 없으면 분을 초로 환산해 폴백한다
(`predictTime1: ''` + `predictTimeSec1` 없음 → 여전히 `null` = 도착 정보 없음).

### 3. 경과 보정이 초 단위가 된다

```dart
final remaining = a.arrSec - elapsed;
return a.copyWith(arrSec: remaining <= 0 ? 0 : remaining);
```

반올림이 사라진다. `bus_card_view.dart:93`의 `floor/ceil/round` 고민은 **표시 시점의
`arrMin` getter 한 곳으로 옮겨간다.**

⚠️ **표시가 한 군데 바뀐다**: 조회 직후 61초 남은 버스가 `2분`(ceil) → `1분`(round).
같은 파일이 이미 "ceil은 최대 59초를 과대 표시해 사용자가 버스를 놓칠 수 있다"며
보정 경로에서 ceil을 거부했다 — 이번에 두 경로의 규칙이 같아진다. 사용자 승인함.

### 4. 축이 초로 그리고 1초마다 움직인다

- `dotPosition(int arrSec)` → `arrSec / (axisRange * 60)`, clamp 동일.
- 점은 `AnimatedPositioned(duration: 1s, curve: linear)`. **`key: ValueKey(routeId)`가
  필수다** — 없으면 Flutter가 Stack 자식을 위치로 매칭해 노선이 뒤바뀐다.
- 15분 축·350pt에서 초당 약 0.39pt 움직인다. 계단이 보이지 않는다.

### 5. 보조 눈금 1분

라벨(`지금·5분·10분·15분`)은 그대로 두고 **레일에 1분 간격 실선 눈금**을 깐다.
라벨을 늘리면 노선 라벨과 부딪힌다(`labelWidth` 34pt).

### 6. 1초 틱 — 새 상태를 만들지 않는다

`buildBusCardView`가 이미 `now`를 받는 순수 함수라, **1초 타이머가 `setState`만** 하면
보정이 다시 돌아 점이 움직인다. 네트워크는 30초 그대로.

수명은 기존 폴링 규칙과 같다 — **펼쳐져 있을 때만** 돌고 접힘·백그라운드에서 멈춘다.

## 손대는 파일

| | 파일 |
|---|---|
| 수정 | `lib/features/bus/domain/bus_arrival.dart` |
| 수정 | `lib/features/bus/domain/bus_card_view.dart` (보정) |
| 수정 | `lib/features/bus/data/tago_response_parser.dart` |
| 수정 | `lib/features/bus/data/gbis_response_parser.dart` |
| 수정 | `lib/features/bus/presentation/widgets/bus_body_axis.dart` |
| 수정 | `lib/features/bus/presentation/widgets/bus_card_host.dart` (1초 틱) |
| 수정 | 픽스처를 만드는 테스트 10개 파일 (`BusArrival(` → `BusArrival.fromMinutes(`) |

## 테스트

**신규**
- 파서 2종이 초를 보존한다(`arrtime 361` → `arrSec 361`, `arrMin 6`).
- 경과 보정이 초 단위다 — 30초 지난 `arrSec 361`이 `331`이 된다(분은 6 유지).
- 60초 미만이 0으로 뭉개지지 않는다(`arrSec 59` → `arrMin 1`, `arrSec 20` → `arrMin 0`).
- `dotPosition`이 초로 다르다 — `359`와 `361`이 다른 값을 준다.
- 보조 눈금이 `axisRange` 개수만큼 그려진다.
- 축의 점에 `ValueKey(routeId)`가 있다(애니메이션 매칭 가드).

**갱신(삭제 아님)**
- 생성자 픽스처를 `fromMinutes`로 기계적 치환.
- ceil을 기대하던 파서 테스트 — `arrSec` 기대로 바꾼다.

## 하지 않는 것

- `axisRange`(15분)는 그대로.
- `간단히` 모양은 문구·배치 모두 그대로(초를 노출하지 않는다 — 카드가 좁다).
- 서울 API 연동은 **별개 작업**이며 키 활성화 전까지 막혀 있다
  (실측 `SERVICE KEY IS NOT REGISTERED`, 2026-07-30).
