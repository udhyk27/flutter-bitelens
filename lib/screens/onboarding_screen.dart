import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'profile_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const OnboardingScreen({super.key, required this.cameras});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  static const List<_OnboardingData> _pages = [
    _OnboardingData(
      icon: Icons.camera_alt_outlined,
      step: '01',
      title: '음식을 찍으면',
      highlight: 'AI가 바로 분석',
      description: '카메라나 갤러리 사진으로 음식 이름, 예상 칼로리, 주요 영양소를 확인해요.',
      accent: Colors.deepOrange,
    ),
    _OnboardingData(
      icon: Icons.local_fire_department_outlined,
      step: '02',
      title: '내 기준에 맞춰',
      highlight: '하루 칼로리 관리',
      description: '키, 몸무게, 활동량을 입력하면 TDEE 기준으로 섭취량을 비교할 수 있어요.',
      accent: Color(0xFFFFB020),
    ),
    _OnboardingData(
      icon: Icons.show_chart_outlined,
      step: '03',
      title: '기록이 쌓이면',
      highlight: '식습관이 보여요',
      description: '분석 기록과 주간 칼로리 흐름을 모아보고, 중요한 식사는 즐겨찾기로 남겨요.',
      accent: Color(0xFF43D19E),
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding({bool goProfile = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(cameras: widget.cameras)),
    );

    if (!goProfile) return;

    await Future.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _nextPage() {
    if (_isLastPage) {
      _completeOnboarding(goProfile: true);
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _pages[_currentPage];

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: Column(
              children: [
                _OnboardingTopBar(
                  currentPage: _currentPage,
                  pageCount: _pages.length,
                  onSkip: () => _completeOnboarding(),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
                  ),
                ),
                _PageDots(
                  currentPage: _currentPage,
                  pageCount: _pages.length,
                  activeColor: data.accent,
                ),
                const SizedBox(height: 28),
                _PrimaryButton(
                  label: _isLastPage ? '내 정보 입력하고 시작' : '다음',
                  icon: _isLastPage
                      ? Icons.person_add_alt_1_outlined
                      : Icons.arrow_forward_rounded,
                  color: data.accent,
                  onTap: _nextPage,
                ),
                const SizedBox(height: 12),
                _TextButton(
                  label: _isLastPage ? '나중에 설정할게요' : '바로 시작',
                  onTap: () => _completeOnboarding(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final String step;
  final String title;
  final String highlight;
  final String description;
  final Color accent;

  const _OnboardingData({
    required this.icon,
    required this.step,
    required this.title,
    required this.highlight,
    required this.description,
    required this.accent,
  });
}

class _OnboardingTopBar extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final VoidCallback onSkip;

  const _OnboardingTopBar({
    required this.currentPage,
    required this.pageCount,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'BITE LENS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
        const Spacer(),
        Text(
          '${currentPage + 1}/$pageCount',
          style: const TextStyle(color: Colors.white30, fontSize: 12),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: onSkip,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '건너뛰기',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FeatureMark(data: data),
        const SizedBox(height: 46),
        Text(
          data.step,
          style: TextStyle(
            color: data.accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          data.title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          data.highlight,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 31,
            fontWeight: FontWeight.w800,
            height: 1.18,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            data.description,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 15,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _FeatureMark extends StatelessWidget {
  final _OnboardingData data;
  const _FeatureMark({required this.data});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 156,
          height: 156,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: data.accent.withValues(alpha: 0.08),
          ),
        ),
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF111111),
            border: Border.all(color: data.accent.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: data.accent.withValues(alpha: 0.18),
                blurRadius: 34,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(data.icon, color: data.accent, size: 46),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final Color activeColor;

  const _PageDots({
    required this.currentPage,
    required this.pageCount,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentPage == i ? 24 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: currentPage == i ? activeColor : Colors.white12,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
