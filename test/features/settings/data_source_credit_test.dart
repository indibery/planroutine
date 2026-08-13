import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/widgets/data_source_list_tile.dart';

import '../../helpers/data_source_agencies.dart';

/// 기관 표는 `test/helpers/data_source_agencies.dart`가 든다 — 스토어 등록정보를 보는
/// `test/deploy/store_listing_credit_test.dart`와 **같은 표**를 써야 한다.
const _agencies = kDataSourceAgencies;

String _clientSource() => busApiClientSource();

void main() {
  group('데이터 출처 표시 — 라이선스 의무', () {
    // 서울특별시 API의 이용허락범위가 `저작자표시`(CC BY) + 공공누리 제1유형
    // (출처표시)이다. 경기도·국토교통부는 요구하지 않지만 함께 적는다.
    //
    // **문구가 렌더되는지가 아니라 문구와 실제 호출이 맞는지를 검사한다.** 렌더링만
    // 보면 소스를 하나 추가하고 출처를 잊어도 통과한다 — 그때가 정확히 라이선스를
    // 어기는 순간이다.
    test('호출하는 기관이 전부 출처에 적혀 있다', () {
      final src = _clientSource();

      for (final (marker, name) in _agencies.entries.map((e) => (e.key, e.value))) {
        if (!src.contains(marker)) continue;
        expect(
          SettingsStrings.dataSourceBody,
          contains(name),
          reason: '$marker(을)를 호출하는데 출처에 $name이 없다 — 라이선스 위반이다',
        );
      }
    });

    test('출처에 적힌 기관은 전부 실제로 호출한다', () {
      // 반대 방향도 지킨다 — 안 쓰는 기관을 출처로 적는 것도 거짓이다.
      // 서울 API는 신청·승인됐지만 키가 등록되지 않아 아직 호출하지 않는다.
      final src = _clientSource();

      for (final (marker, name) in _agencies.entries.map((e) => (e.key, e.value))) {
        if (src.contains(marker)) continue;
        expect(
          SettingsStrings.dataSourceBody,
          isNot(contains(name)),
          reason: '출처에 $name을 적었는데 $marker를 호출하지 않는다',
        );
      }
    });

    testWidgets('설정 타일이 제목과 출처를 함께 보여준다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: DataSourceListTile()),
      ));

      expect(find.text(SettingsStrings.dataSourceTitle), findsOneWidget);
      expect(find.text(SettingsStrings.dataSourceBody), findsOneWidget);
    });

    testWidgets('탭이 없다 — 정보성 타일이다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: DataSourceListTile()),
      ));

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.onTap, isNull);
    });
  });
}
