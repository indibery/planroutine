import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
import '../../data/onboarding_repository.dart';

/// 3페이지 PageView 온보딩 화면.
/// 마지막 페이지에서 "시작하기" 또는 상단 "건너뛰기"를 탭하면
/// [OnboardingRepository.markDone]을 호출하고 `/calendar`로 이동한다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      icon: Icons.upload_file,
      heading: '작년 일정 가져오기',
      body: '나이스 CSV를 업로드하면\n작년 업무 일정이 자동 등록됩니다',
    ),
    _OnboardingPageData(
      icon: Icons.checklist_rtl,
      heading: '검토하고 확정',
      body: '슬라이드로 올해 일정을\n확정하거나 삭제하세요',
    ),
    _OnboardingPageData(
      icon: Icons.calendar_month,
      heading: '캘린더로 관리',
      body: '확정된 일정이 캘린더에\n자동으로 등록됩니다',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingRepository().markDone();
    if (!mounted) return;
    context.go(AppRoutes.calendar);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            // 상단: 로고/타이틀 + 건너뛰기 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spacing20,
                AppSizes.spacing16,
                AppSizes.spacing16,
                0,
              ),
              child: Row(
                children: [
                  const Spacer(),
                  SizedBox(
                    height: 36,
                    child: isLast
                        ? const SizedBox.shrink()
                        : TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.sub,
                            ),
                            child: const Text(
                              '건너뛰기',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.sub,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            const BrandLogo(size: 80),
            const SizedBox(height: AppSizes.spacing16),
            const Text(
              '공직플랜',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.6,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSizes.spacing4),
            const Text(
              'GONGJIKPLAN · 2026',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.0,
                color: AppColors.goldMuted,
              ),
            ),
            const SizedBox(height: AppSizes.spacing32),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),
            // 하단 고정: 페이지 인디케이터 + 시작하기 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spacing20,
                AppSizes.spacing16,
                AppSizes.spacing20,
                AppSizes.spacing32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 6 : 4,
                        height: active ? 6 : 4,
                        decoration: BoxDecoration(
                          color: active ? AppColors.gold : AppColors.faint,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSizes.spacing20),
                  SizedBox(
                    width: double.infinity,
                    child: isLast
                        ? GoldGradientButton(
                            label: '시작하기',
                            height: 52,
                            onPressed: _finish,
                          )
                        : const SizedBox(height: 52),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.heading,
    required this.body,
  });

  final IconData icon;
  final String heading;
  final String body;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, color: AppColors.gold, size: 48),
          const SizedBox(height: AppSizes.spacing20),
          Text(
            data.heading,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.6,
              color: AppColors.sub,
            ),
          ),
        ],
      ),
    );
  }
}
