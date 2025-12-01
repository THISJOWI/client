import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thisjowi/i18n/translations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  List<OnboardingPage> _getPages(BuildContext context) {
    return [
      OnboardingPage(
        title: 'Welcome to ThisJowi'.i18n,
        description: 'Your secure password manager'.i18n,
        icon: Icons.lock_person_rounded,
        color: AppColors.primary,
      ),
      OnboardingPage(
        title: 'Secure Storage'.i18n,
        description: 'All your passwords encrypted and safe'.i18n,
        icon: Icons.security,
        color: AppColors.accent,
      ),
      OnboardingPage(
        title: 'Offline Access'.i18n,
        description: 'Access your data anytime, anywhere'.i18n,
        icon: Icons.cloud_off,
        color: AppColors.secondary,
      ),
      OnboardingPage(
        title: 'Cloud Sync'.i18n,
        description: 'Keep your data synced across all devices'.i18n,
        icon: Icons.cloud_sync,
        color: AppColors.primary,
      ),
      OnboardingPage(
        title: 'Biometric Security'.i18n,
        description: 'Quick and secure access with your fingerprint'.i18n,
        icon: Icons.fingerprint_rounded,
        color: AppColors.accent,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });

    // Reset and replay animations
    _fadeController.reset();
    _scaleController.reset();
    _fadeController.forward();
    _scaleController.forward();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip'.i18n,
                    style: TextStyle(
                      color: AppColors.text.withOpacity(0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // PageView with onboarding pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(pages[index]);
                },
              ),
            ),

            // Page indicators
            _buildPageIndicators(pages.length),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_ios, color: AppColors.text),
                          const SizedBox(width: 4),
                          Text(
                            'Back'.i18n,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(width: 80),

                  // Next/Finish button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _completeOnboarding();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _currentPage < pages.length - 1
                              ? 'Next'.i18n
                              : 'Get Started'.i18n,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Icon
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: page.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: page.color.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  page.icon,
                  size: 80,
                  color: page.color,
                ),
              ),
            ),

            const SizedBox(height: 60),

            // Title
            Text(
              page.title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Description
            Text(
              page.description,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.text.withOpacity(0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicators(int pageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppColors.primary
                : AppColors.text.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
