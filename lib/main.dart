import 'package:flutter/material.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/utils/api_config.dart';
import 'package:thisjowi/utils/env_loader.dart';
import 'package:thisjowi/screens/auth/loginScreen.dart';
import 'package:thisjowi/screens/auth/registerScreen.dart';
import 'package:thisjowi/screens/splash/splash_screen.dart';
import 'package:thisjowi/screens/onboarding/onboarding_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1️⃣ PRIMERO: Cargar .env ANTES de cualquier otra cosa
  await EnvLoader.load();
  
  // 2️⃣ LUEGO: Mostrar configuración del API
  ApiConfig.printConfig();
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "ThisJowi",
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.text,
          selectionColor: AppColors.text.withOpacity(0.3),
          selectionHandleColor: AppColors.text,
        ),
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
      home: const SplashScreen(),
    );
  }
}
