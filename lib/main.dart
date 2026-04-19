import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/trash/presentation/providers/trash_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 30일 이상 경과한 휴지통 항목을 앱 시작 시 1회 영구 삭제한다.
  // 실패해도 앱 기동은 차단하지 않음.
  final container = ProviderContainer();
  try {
    await purgeExpiredTrash(container);
  } catch (_) {
    // 삭제 실패 시 다음 시작에 재시도 — 현재 기동 흐름은 그대로 유지
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PlanRoutineApp(),
    ),
  );
}
