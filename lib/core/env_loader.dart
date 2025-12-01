import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cargador de variables de entorno desde .env
/// Se ejecuta PRIMERO antes de cualquier otra cosa
class EnvLoader {
  static final Map<String, String> _env = {};
  static bool _initialized = false;

  /// Carga el archivo .env desde assets
  static Future<void> load() async {
    if (_initialized) return;

    try {
      debugPrint('Loading .env file...');
      final envContent = await rootBundle.loadString('.env');
      
      for (var line in envContent.split('\n')) {
        line = line.trim();
        
        // Skip comments and empty lines
        if (line.isEmpty || line.startsWith('#')) continue;
        
        // Parse key=value
        final parts = line.split('=');
        if (parts.length != 2) continue;
        
        final key = parts[0].trim();
        final value = parts[1].trim();
        _env[key] = value;
      }
      
      _initialized = true;
      debugPrint('✅ .env loaded: ${_env.keys.toList()}');
    } catch (e) {
      debugPrint('❌ Error loading .env: $e');
      rethrow;
    }
  }

  /// Obtener valor de variable de entorno
  static String? get(String key) => _env[key];

  /// Obtener valor requerido (lanza excepción si no existe)
  static String getRequired(String key) {
    final value = _env[key];
    if (value == null) {
      throw Exception('Environment variable "$key" is not configured');
    }
    return value;
  }

  /// Obtener valor como int
  static int getInt(String key, {int defaultValue = 0}) {
    final value = _env[key];
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  /// Obtener valor requerido como int
  static int getRequiredInt(String key) {
    final value = getRequired(key);
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw Exception('Environment variable "$key" must be a number');
    }
    return parsed;
  }
}
