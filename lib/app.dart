import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/import/presentation/providers/import_providers.dart';

/// 앱 루트 위젯.
///
/// GoRouter를 state에 보관해, 다른 앱(카카오톡/메일/파일 앱)에서 공유받은 CSV를
/// 열었을 때 `_router.go(AppRoutes.import)`로 Import 화면으로 직접 전환할 수 있게
/// 한다. Running/Cold start 양쪽 경로를 모두 처리.
class PlanRoutineApp extends ConsumerStatefulWidget {
  const PlanRoutineApp({super.key, this.onboardingDone = true});

  /// 온보딩 완료 여부 — 부팅 시 [OnboardingRepository.isDone]으로 읽어서 주입.
  final bool onboardingDone;

  @override
  ConsumerState<PlanRoutineApp> createState() => _PlanRoutineAppState();
}

class _PlanRoutineAppState extends ConsumerState<PlanRoutineApp> {
  late final GoRouter _router;
  StreamSubscription<List<SharedMediaFile>>? _sharingSub;

  @override
  void initState() {
    super.initState();
    _router = createRouter(onboardingDone: widget.onboardingDone);
    _setupSharingListener();
  }

  Future<void> _setupSharingListener() async {
    // 앱 실행 중일 때 공유 수신
    _sharingSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedFiles,
      onError: (_) {},
    );

    // 앱이 공유 인텐트로 cold start된 경우
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initial.isNotEmpty) {
      _handleSharedFiles(initial);
      // 동일 파일이 재처리되지 않도록 리셋
      ReceiveSharingIntent.instance.reset();
    }
  }

  /// CSV 확장자 파일 하나만 취해 Import 화면으로 전환하고 파싱을 시작한다.
  void _handleSharedFiles(List<SharedMediaFile> files) {
    String? csvPath;
    for (final f in files) {
      if (f.path.toLowerCase().endsWith('.csv')) {
        csvPath = f.path;
        break;
      }
    }
    if (csvPath == null) return;

    _router.go(AppRoutes.import);
    // 다음 프레임에 파싱 시작 — Import 화면이 mount된 뒤 상태가 바뀌도록
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(importStateProvider.notifier).importFromPath(csvPath!);
    });
  }

  @override
  void dispose() {
    _sharingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      locale: const Locale('ko', 'KR'),
    );
  }
}
