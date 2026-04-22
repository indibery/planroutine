import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/import/presentation/providers/import_providers.dart';

/// 앱 루트 위젯.
///
/// 다른 앱(카카오톡/메일/파일 앱)이 "공직플랜으로 열기"로 넘긴 CSV 파일 URL을
/// AppDelegate가 method channel(`planroutine/shared_file`)로 전달한다.
/// 앱 cold-start(`getPending`) + running(`onFileShared` push) 양쪽을 모두 처리.
class PlanRoutineApp extends ConsumerStatefulWidget {
  const PlanRoutineApp({super.key, this.onboardingDone = true});

  /// 온보딩 완료 여부 — 부팅 시 [OnboardingRepository.isDone]으로 읽어서 주입.
  final bool onboardingDone;

  @override
  ConsumerState<PlanRoutineApp> createState() => _PlanRoutineAppState();
}

class _PlanRoutineAppState extends ConsumerState<PlanRoutineApp> {
  static const _sharedFileChannel = MethodChannel('planroutine/shared_file');

  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createRouter(onboardingDone: widget.onboardingDone);
    _setupSharedFileListener();
  }

  Future<void> _setupSharedFileListener() async {
    // Running 상태에서 외부 앱이 파일을 공유하면 native가 push 한다
    _sharedFileChannel.setMethodCallHandler((call) async {
      if (call.method == 'onFileShared' && call.arguments is String) {
        _handleSharedFile(call.arguments as String);
      }
    });

    // Cold-start로 열린 경우 native가 버퍼에 담아둔 경로를 한 번 꺼낸다
    try {
      final initial = await _sharedFileChannel.invokeMethod<String>('getPending');
      if (initial != null && initial.isNotEmpty) {
        _handleSharedFile(initial);
      }
    } catch (_) {
      // 채널 아직 준비 안 된 경우 무시 (native가 나중에 onFileShared로 push)
    }
  }

  void _handleSharedFile(String path) {
    if (!path.toLowerCase().endsWith('.csv')) return;

    _router.go(AppRoutes.import);
    // Import 화면이 mount된 다음 프레임에 파싱 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(importStateProvider.notifier).importFromPath(path);
    });
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
