import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thisjowi/services/biometric_service.dart';
import 'package:thisjowi/services/auth_service.dart';
import 'package:thisjowi/screens/auth/biometric_auth_screen.dart';
import 'package:thisjowi/components/bottomNavigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  final BiometricService _biometricService = BiometricService();
  final AuthService _authService = AuthService();
  
  // Keys for SharedPreferences
  static const String _appOpenCountKey = 'app_open_count';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();

    // Check if it's the first time and navigate accordingly
    _checkFirstTimeAndBiometric();
  }

  Future<void> _checkFirstTimeAndBiometric() async {
    // Wait for the animation to complete
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('onboarding_completed') ?? false;
    
    // Increment app open count
    final appOpenCount = (prefs.getInt(_appOpenCountKey) ?? 0) + 1;
    await prefs.setInt(_appOpenCountKey, appOpenCount);

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      // First time: Navigate to onboarding
      Navigator.of(context).pushReplacementNamed('/onboarding');
      return;
    }

    // Check if biometric lock should be shown
    // Show if: app has been opened more than once AND user has session AND biometrics are available
    final shouldShowBiometric = await _shouldShowBiometricAuth(prefs, appOpenCount);
    
    if (shouldShowBiometric) {
      _showBiometricAuth();
    } else {
      // Navigate based on session status
      _navigateToMainScreen();
    }
  }
  
  Future<bool> _shouldShowBiometricAuth(SharedPreferences prefs, int appOpenCount) async {
    // Only show if app has been opened more than once
    if (appOpenCount <= 1) {
      return false;
    }
    
    // Check if user has a valid session (token)
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    
    // Check if biometric lock is enabled by user in settings
    final biometricLockEnabled = await _biometricService.isBiometricLockEnabled();
    if (!biometricLockEnabled) {
      return false;
    }
    
    // Check if device supports biometrics
    final canUseBiometrics = await _biometricService.canCheckBiometrics();
    final isDeviceSupported = await _biometricService.isDeviceSupported();
    
    return canUseBiometrics && isDeviceSupported;
  }
  
  /// Navigate to the appropriate screen based on authentication status
  void _navigateToMainScreen() {
    _authService.getToken().then((token) {
      if (!mounted) return;
      
      if (token != null && token.isNotEmpty) {
        // User has valid session, go to Home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MyBottomNavigation()),
        );
      } else {
        // No session, go to Login
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }
  
  void _showBiometricAuth() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return BiometricAuthScreen(
            onAuthenticated: () {
              // Successfully authenticated, go to Home (user already has session)
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MyBottomNavigation()),
              );
            },
            onSkipped: () {
              // User chose to skip biometric, go to Login to enter password
              Navigator.of(context).pushReplacementNamed('/login');
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with glow effect
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // App name
                Text(
                  'THISJOWI',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 16),

                // Loading indicator
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary.withOpacity(0.7),
                    ),
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
