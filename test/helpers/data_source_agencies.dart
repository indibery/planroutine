import 'dart:io';

/// 호출하는 기관 ↔ 출처 문구에 있어야 할 낱말.
///
/// 키는 `bus_api_client.dart`에 실제로 박혀 있는 문자열이다(공공데이터포털 기관코드,
/// 또는 호스트). 그 문자열이 있으면 그 기관을 호출한다는 뜻이다.
///
/// **이 표가 단일 원본이다.** 앱 안 문구(`data_source_credit_test.dart`)와 스토어
/// 등록정보(`store_listing_credit_test.dart`) 두 가드가 같은 표를 본다 — 한쪽에만
/// 기관을 추가하면 다른 쪽이 조용히 검사를 빠뜨린다. 소스를 추가하고 출처를 잊는
/// 순간이 정확히 라이선스를 어기는 순간이다.
const kDataSourceAgencies = {
  '1613000': '국토교통부', // TAGO
  '6410000': '경기도', // GBIS
  'ws.bus.go.kr': '서울', // 서울특별시 — 아직 미사용
};

/// 실제 호출부. 상대 경로는 `flutter test`의 CWD(리포 루트) 기준이다.
String busApiClientSource() =>
    File('lib/features/bus/data/bus_api_client.dart').readAsStringSync();
