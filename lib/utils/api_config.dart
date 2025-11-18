import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:thisjowi/utils/env_loader.dart';

/// Configuración centralizada de API para el proyecto ThisJowi
/// Lee todas las variables desde .env
class ApiConfig {
  /// Obtiene la URL base del API
  static String get baseUrl {
    // Si hay una URL manual configurada, usarla
    if (_manualBaseUrl != null) {
      return _manualBaseUrl!;
    }
    
    final ip = EnvLoader.getRequired('LOCAL_NETWORK_IP');
    final port = EnvLoader.getRequiredInt('GATEWAY_PORT');
    
    // Limpiar IP si tiene protocolo
    var cleanIp = ip.replaceAll('http://', '').replaceAll('https://', '');
    
    return 'http://$cleanIp:$port';
  }
  
  /// URL completa para el servicio de autenticación
  static String get authUrl {
    final path = EnvLoader.getRequired('AUTH_SERVICE_URL');
    return '$baseUrl$path';
  }
  
  /// URL completa para el servicio de notas
  static String get notesUrl {
    final path = EnvLoader.getRequired('NOTES_SERVICE_URL');
    return '$baseUrl$path';
  }
  
  /// URL completa para el servicio de contraseñas
  static String get passwordsUrl {
    final path = EnvLoader.getRequired('PASSWORD_SERVICE_URL');
    return '$baseUrl$path';
  }
  
  /// Timeout para las peticiones HTTP (en segundos)
  static int get requestTimeout => EnvLoader.getRequiredInt('REQUEST_TIMEOUT');
  
  /// Headers comunes para todas las peticiones
  static Map<String, String> get commonHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  /// Headers con autenticación
  static Map<String, String> authHeaders(String token) => {
    ...commonHeaders,
    'Authorization': 'Bearer $token',
  };
  
  /// Método para debugging - muestra la configuración actual
  static void printConfig() {
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('🔧 ThisJowi API Configuration');
      debugPrint('═══════════════════════════════════════');
      debugPrint('Platform: ${_getPlatformName()}');
      debugPrint('Base URL: $baseUrl');
      debugPrint('Auth URL: $authUrl');
      debugPrint('Notes URL: $notesUrl');
      debugPrint('Passwords URL: $passwordsUrl');
      debugPrint('Timeout: ${requestTimeout}s');
      debugPrint('═══════════════════════════════════════');
    }
  }
  
  static String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
  
  /// Permite sobreescribir manualmente la URL base (útil para testing)
  static String? _manualBaseUrl;
  
  static void setManualBaseUrl(String url) {
    _manualBaseUrl = url;
    if (kDebugMode) {
      debugPrint('API Base URL manually set to: $url');
    }
  }
  
  static void clearManualBaseUrl() {
    _manualBaseUrl = null;
  }
  
  /// Versión de la API
  static String get apiVersion => 'v1';
}

