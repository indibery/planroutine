import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// integration_test의 takeScreenshot() 결과를 `docs/screenshots/<name>.png`로 저장.
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final file = File('docs/screenshots/$name.png');
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);
        // ignore: avoid_print
        print('[screenshot] saved ${file.path} (${bytes.length} bytes)');
        return true;
      },
    );
