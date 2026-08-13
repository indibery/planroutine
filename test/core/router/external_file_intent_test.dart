import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/router/app_router.dart';

/// 외부 앱이 CSV로 앱을 열 때 Flutter가 넘기는 초기 라우트 판정.
///
/// 이 판정이 없으면 화면에 **Page Not Found**가 뜬다. 실측으로 두 번 데였다 —
/// iOS의 `file://`(문서에 기록됨)과 Android의 `content://`(2026-08-14 에뮬레이터).
/// 후자는 가드·빌드·네이티브 복사가 전부 통과한 뒤에도 화면만 깨져 있었다.
void main() {
  group('외부 파일 인텐트 판정', () {
    test('Android content:// — 확장자도 파일명도 없다', () {
      // 실측 URI 그대로. 여기서 false가 나오면 공유·열기가 Page Not Found로 끝난다.
      expect(
        isExternalFileIntent(
          Uri.parse('content://media/external/file/1000000018'),
        ),
        isTrue,
      );
      expect(
        isExternalFileIntent(
          Uri.parse(
            'content://com.android.providers.downloads.documents/document/42',
          ),
        ),
        isTrue,
      );
    });

    test('iOS file:// — scheme과 확장자 둘 다 있다', () {
      expect(
        isExternalFileIntent(Uri.parse('file:///private/var/tmp/작년업무.csv')),
        isTrue,
      );
      // 확장자가 없어도 scheme으로 걸린다.
      expect(isExternalFileIntent(Uri.parse('file:///tmp/noext')), isTrue);
    });

    test('.csv 접미사만 있어도 걸린다', () {
      expect(isExternalFileIntent(Uri.parse('/Downloads/작년업무.csv')), isTrue);
      // 대소문자를 가리지 않는다.
      expect(isExternalFileIntent(Uri.parse('/Downloads/DATA.CSV')), isTrue);
    });

    test('앱 안의 평범한 경로는 가로채지 않는다', () {
      // 여기서 true가 되면 정상 탐색이 전부 /import로 튄다.
      for (final path in [
        '/today',
        '/calendar',
        '/schedule',
        '/settings',
        '/trash',
        '/import',
        '/bus/stops',
        '/bus/settings',
        '/onboarding',
      ]) {
        expect(
          isExternalFileIntent(Uri.parse(path)),
          isFalse,
          reason: '$path 가 외부 파일 인텐트로 오판됐다',
        );
      }
    });

    test('https 같은 다른 scheme은 가로채지 않는다', () {
      expect(
        isExternalFileIntent(Uri.parse('https://example.com/a.pdf')),
        isFalse,
      );
      // ⚠️ 단 `.csv`로 끝나는 http URL은 걸린다 — 지금은 그런 링크를 열 경로가
      // 없으므로 두고 있다. 웹 링크를 받게 되면 이 줄이 먼저 깨질 것이다.
      expect(
        isExternalFileIntent(Uri.parse('https://example.com/a.csv')),
        isTrue,
      );
    });
  });
}
