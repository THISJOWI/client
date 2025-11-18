import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/screens/notes/NotesScreen.dart';
import 'package:thisjowi/screens/otp/TOPT.dart';
import 'package:thisjowi/screens/password/PasswordScreen.dart';
import 'package:thisjowi/screens/settings/SettingScreen.dart';

class MyBottomNavigation extends StatefulWidget {
  const MyBottomNavigation({super.key});

  @override
  State<MyBottomNavigation> createState() => _MyBottomNavigationState();
}

class _MyBottomNavigationState extends State<MyBottomNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    Center(
      child: PasswordScreen(),
    ),
    Center(
      child: OtpScreen(),
    ),
    const NotesScreen(),
    const SettingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _pages[_currentIndex],
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.text.withOpacity(0.08),
              border: Border.all(
                color: AppColors.text.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                ),
                child: BottomNavigationBar(
                  showSelectedLabels: false,
                  showUnselectedLabels: false,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: AppColors.text,
                  unselectedItemColor: AppColors.text.withOpacity(0.5),
                  elevation: 0,
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home, size: 24),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.security, size: 24),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.note_add, size: 24),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.settings, size: 24),
                      label: '',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}