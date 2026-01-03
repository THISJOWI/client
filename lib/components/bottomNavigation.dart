import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/screens/otp/TOPT.dart';
import 'package:thisjowi/screens/home/HomeScreen.dart';
import 'package:thisjowi/screens/settings/SettingScreen.dart';

// GlobalKey para acceder al estado de la navegación
final GlobalKey<MyBottomNavigationState> bottomNavigationKey = GlobalKey<MyBottomNavigationState>();

class MyBottomNavigation extends StatefulWidget {
  const MyBottomNavigation({super.key});

  @override
  State<MyBottomNavigation> createState() => MyBottomNavigationState();
}

class MyBottomNavigationState extends State<MyBottomNavigation> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const OtpScreen(),
    const SettingScreen(),
  ];

  /// Método público para cambiar de pestaña
  void navigateToTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() => _currentIndex = index);
    }
  }

  /// Navegar a la pestaña de OTP (índice 1)
  void navigateToOtp() => navigateToTab(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: AppColors.text.withOpacity(0.1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildNavItem(0, Icons.house_rounded, Icons.house_outlined, isFirst: true),
                      _buildNavItem(1, Icons.shield_rounded, Icons.shield_outlined),
                      _buildNavItem(2, Icons.settings_rounded, Icons.settings_outlined, isLast: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, {bool isFirst = false, bool isLast = false}) {
    final isSelected = _currentIndex == index;
    
    BorderRadius borderRadius;
    if (isFirst) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(25),
        bottomLeft: Radius.circular(25),
        topRight: Radius.circular(20),
        bottomRight: Radius.circular(20),
      );
    } else if (isLast) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(20),
        bottomLeft: Radius.circular(20),
        topRight: Radius.circular(25),
        bottomRight: Radius.circular(25),
      );
    } else {
      borderRadius = BorderRadius.circular(20);
    }
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, rawValue, child) {
          final value = rawValue.clamp(0.0, 1.0);
          return Transform.scale(
            scale: 1.0 + (value * 0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: value > 0.01
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.25 * value),
                          Colors.white.withOpacity(0.12 * value),
                          Colors.white.withOpacity(0.05 * value),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      )
                    : null,
                border: value > 0.01
                    ? Border.all(
                        color: Colors.white.withOpacity(0.35 * value),
                        width: 1.5,
                      )
                    : null,
                boxShadow: value > 0.01
                    ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.15 * value),
                          blurRadius: 16 * value,
                          spreadRadius: -2,
                          offset: Offset(0, 2 * value),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25 * value),
                          blurRadius: 12 * value,
                          spreadRadius: -4,
                          offset: Offset(0, 6 * value),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                size: 24,
                color: Color.lerp(
                  AppColors.text.withOpacity(0.4),
                  Colors.white,
                  value,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}