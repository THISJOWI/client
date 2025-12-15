import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/core/api_config.dart';
import 'package:thisjowi/core/env_loader.dart';
import 'package:thisjowi/screens/auth/loginScreen.dart';
import 'package:thisjowi/screens/auth/registerScreen.dart';
import 'package:thisjowi/screens/otp/OtpQrScannerScreen.dart';
import 'package:thisjowi/screens/splash/splash_screen.dart';
import 'package:thisjowi/screens/onboarding/onboarding_screen.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar el estilo de la barra de estado (iconos claros para fondo oscuro)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // Iconos claros (Android)
    statusBarBrightness: Brightness.dark, // Barra oscura = iconos claros (iOS)
    systemNavigationBarColor: AppColors.bottomNavBar,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  
  await EnvLoader.load();
  
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
      
      // Localization support
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        // Si el idioma del dispositivo es español (cualquier variante), usar 'es'
        if (locale?.languageCode == 'es') {
          return const Locale('es');
        }
        // Por defecto, usar inglés
        return const Locale('en');
      },
      builder: (context, child) => I18n(child: child!),
      
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        // Configurar AppBar para que use iconos claros
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
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
        '/otp/qrscan': (context) => const OtpQrScannerScreen(),
      },
      home: const SplashScreen(),
    );
  }
}
