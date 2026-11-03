import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_lock_routes.dart';

/// 셸 builder가 받은 경로를 기록하는 탐침.
class _Probe extends StatelessWidget {
  const _Probe({required this.path, required this.log, required this.child});
  final String path;
  final List<String> log;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (log.isEmpty || log.last != path) log.add(path);
    return child;
  }
}

void main() {
  group('guidanceRouteRequiresUnlock', () {
    test('목록과 새 기록은 잠금이 필요 없다', () {
      expect(guidanceRouteRequiresUnlock('/guidance'), isFalse);
      expect(guidanceRouteRequiresUnlock('/guidance/new'), isFalse);
      expect(guidanceRouteRequiresUnlock('/guidance/'), isFalse);
    });

    test('예전 기록을 여는 경로는 잠금이 필요하다', () {
      for (final p in [
        '/guidance/record/1',
        '/guidance/record/1/edit',
        '/guidance/record/1/history',
        '/guidance/record/1/transcript/2',
        '/guidance/trash',
        '/guidance/whatever',
      ]) {
        expect(guidanceRouteRequiresUnlock(p), isTrue, reason: p);
      }
    });
  });

  testWidgets('셸 builder가 push한 하위 경로를 받고 pop 뒤 /guidance로 돌아온다', (
    tester,
  ) async {
    final log = <String>[];
    final router = GoRouter(
      initialLocation: '/guidance',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              _Probe(path: state.uri.path, log: log, child: child),
          routes: [
            GoRoute(
              path: '/guidance',
              builder: (context, state) => Builder(
                builder: (context) => TextButton(
                  onPressed: () => context.push('/guidance/record/1'),
                  child: const Text('open'),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'record/:id',
                  builder: (context, state) => const Text('detail'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(log, ['/guidance', '/guidance/record/1', '/guidance']);
  });
}
