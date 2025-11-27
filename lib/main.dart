import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:thisjowi/core/appColors.dart';
import 'package:thisjowi/utils/api_config.dart';
import 'package:thisjowi/utils/env_loader.dart';
import 'package:thisjowi/screens/auth/loginScreen.dart';
import 'package:thisjowi/screens/auth/registerScreen.dart';
import 'package:thisjowi/screens/splash/splash_screen.dart';
import 'package:thisjowi/screens/onboarding/onboarding_screen.dart';
import 'package:thisjowi/backend/service/database_service.dart';
import 'package:thisjowi/backend/service/connectivity_service.dart';
import 'package:thisjowi/backend/service/sync_service.dart';


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
  
  try {
    await DatabaseService().database;
    print('✅ Base de datos local inicializada correctamente');
  } catch (e) {
    print('⚠️ Error al inicializar base de datos: $e');
  }
  
  // 4️⃣ Inicializar servicios de conectividad y sincronización
  final connectivityService = ConnectivityService();
  // ignore: unused_local_variable
  final syncService = SyncService();
  
  print('✅ Servicios de offline mode inicializados');
  print('📡 Estado de conexión: ${connectivityService.isOnline ? "Online" : "Offline"}');
  
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
      },
      home: const SplashScreen(),
    );
  }
}
