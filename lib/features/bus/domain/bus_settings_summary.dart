import '../../../core/constants/app_strings.dart';
import 'bus_settings.dart';

/// `기능 관리`의 켜진 버스 행 부제.
///
/// 순수 함수로 둔다 — 이 리포가 요약 문구를 다루는 방식이다
/// (`buildBusCardView`·`buildTodayView`·`computeNotifications`). 위젯 안에서
/// 조립하면 분기를 유닛 테스트로 고정할 수 없다.
///
/// 켜짐 여부는 보지 않는다 — **켜진 행에만** 쓰인다(꺼진 행은 기능 설명을 보인다).
String buildBusSettingsSummary(BusSettings settings) {
  var count = 0;
  if (settings.departure != null) count++;
  if (settings.arrival != null) count++;

  if (count == 0) return BusStrings.summaryNoStop;
  return BusStrings.summaryStops(count);
}
