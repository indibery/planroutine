import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/import/presentation/providers/import_providers.dart';
import 'features/settings/presentation/providers/theme_mode_provider.dart';

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
    // 선택된 테마 모드(기본 시스템) + 기기 밝기 → effective brightness.
    // 팔레트가 전역 단일이라 MaterialApp에 theme 하나만 주고, effective에 맞춰
    // AppColors 팔레트를 동기화한다. 시스템 모드는 기기 밝기 변경 시 rebuild로 반영.
    final mode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final effective = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };
    AppColors.applyBrightness(effective);

    return MaterialApp.router(
      title: AppStrings.appName,
      theme: AppTheme.of(effective),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      // 밝기가 바뀌면 라우트 하위 전체를 재생성해 전역 AppColors를 확실히 반영한다.
      // (라우터 상태는 상위라 현재 탭은 유지) — 위젯별 리빌드 순서·State 유지에
      // 의존하지 않아, 탭을 오간 뒤 테마를 바꿔도 텍스트가 이전 색으로 남지 않는다.
      builder: (context, child) => KeyedSubtree(
        key: ValueKey(effective),
        child: child ?? const SizedBox.shrink(),
      ),
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
