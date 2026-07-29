import '../../../core/constants/app_strings.dart';
import 'bus_settings.dart';

/// 설정 탭에 남는 버스 요약 한 줄.
///
/// 순수 함수로 둔다 — 이 리포가 요약 문구를 다루는 방식이다
/// (`buildFilterSummary`·`buildBusCardView`·`buildTodayView`). 위젯 안에서
/// 조립하면 분기를 유닛 테스트로 고정할 수 없다.
///
/// **켜짐 여부를 먼저 본다.** 꺼 둔 사용자의 설정에도 정류장은 남아 있으므로,
/// 정류장 수를 먼저 보면 꺼진 기능이 켜진 것처럼 읽힌다.
String buildBusSettingsSummary(BusSettings settings) {
  if (!settings.enabled) return BusStrings.summaryOff;

  var count = 0;
  if (settings.departure != null) count++;
  if (settings.arrival != null) count++;

  if (count == 0) return BusStrings.summaryNoStop;
  return BusStrings.summaryStops(count);
}
