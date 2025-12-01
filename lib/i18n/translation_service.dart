

import 'package:flutter/material.dart';

/// Servicio de traducción más flexible que permite traducciones dinámicas
class TranslationService {
  static final Map<String, Map<String, String>> _dynamicTranslations = {};
  static final Map<String, Map<String, String>> _autoTranslations = {
    // OTP Screen
    "Code copied": {"en": "Code copied", "es": "Código copiado"},
    "Add OTP": {"en": "Add OTP", "es": "Añadir OTP"},
    "Account name": {"en": "Account name", "es": "Nombre de cuenta"},
    "Issuer": {"en": "Issuer", "es": "Emisor"},
    "Secret key": {"en": "Secret key", "es": "Clave secreta"},
    "Add": {"en": "Add", "es": "Añadir"},
    "Name and secret are required": {"en": "Name and secret are required", "es": "Nombre y clave son requeridos"},
    "Invalid secret key": {"en": "Invalid secret key", "es": "Clave secreta inválida"},
    "OTP added": {"en": "OTP added", "es": "OTP añadido"},
    "Import OTP URI": {"en": "Import OTP URI", "es": "Importar URI OTP"},
    "Paste the otpauth:// URI from your authenticator app": {"en": "Paste the otpauth:// URI from your authenticator app", "es": "Pega la URI otpauth:// de tu app autenticadora"},
    "OTP URI": {"en": "OTP URI", "es": "URI OTP"},
    "Import": {"en": "Import", "es": "Importar"},
    "Invalid OTP URI": {"en": "Invalid OTP URI", "es": "URI OTP inválida"},
    "OTP imported": {"en": "OTP imported", "es": "OTP importado"},
    "Delete OTP?": {"en": "Delete OTP?", "es": "¿Eliminar OTP?"},
    "Are you sure you want to delete": {"en": "Are you sure you want to delete", "es": "¿Estás seguro de que deseas eliminar"},
    "OTP deleted": {"en": "OTP deleted", "es": "OTP eliminado"},
    "Authenticator": {"en": "Authenticator", "es": "Autenticador"},
    "Import URI": {"en": "Import URI", "es": "Importar URI"},
    "Scan QR": {"en": "Scan QR", "es": "Escanear QR"},
    "Search...": {"en": "Search...", "es": "Buscar..."},
    "No OTP entries yet": {"en": "No OTP entries yet", "es": "Aún no hay entradas OTP"},
    "Add your first authenticator code": {"en": "Add your first authenticator code", "es": "Añade tu primer código de autenticación"},
    "Add manually": {"en": "Add manually", "es": "Añadir manualmente"},
    "Tap to copy": {"en": "Tap to copy", "es": "Toca para copiar"},
    
    // Home Screen
    "Delete password?": {"en": "Delete password?", "es": "¿Eliminar contraseña?"},
    "Password deleted": {"en": "Password deleted", "es": "Contraseña eliminada"},
    "Delete Note?": {"en": "Delete Note?", "es": "¿Eliminar nota?"},
    "Note deleted": {"en": "Note deleted", "es": "Nota eliminada"},
    "Error deleting note": {"en": "Error deleting note", "es": "Error al eliminar nota"},
    "User copied": {"en": "User copied", "es": "Usuario copiado"},
    "Password copied": {"en": "Password copied", "es": "Contraseña copiada"},
    "User": {"en": "User", "es": "Usuario"},
    "No data yet": {"en": "No data yet", "es": "Aún no hay datos"},
  };

  /// Agrega una traducción dinámica
  static void addTranslation(String key, Map<String, String> translations) {
    _dynamicTranslations[key] = translations;
  }

  /// Agrega múltiples traducciones dinámicas
  static void addTranslations(Map<String, Map<String, String>> translations) {
    _dynamicTranslations.addAll(translations);
  }

  /// Traduce un texto dinámicamente
  static String translate(String text, String locale) {
    // Primero busca en traducciones dinámicas
    if (_dynamicTranslations.containsKey(text)) {
      return _dynamicTranslations[text]?[locale] ?? text;
    }
    
    // Luego busca en traducciones automáticas
    if (_autoTranslations.containsKey(text)) {
      return _autoTranslations[text]?[locale] ?? text;
    }
    
    // Si no se encuentra, devuelve el texto original
    return text;
  }

  /// Limpia todas las traducciones dinámicas
  static void clearDynamicTranslations() {
    _dynamicTranslations.clear();
  }
}

/// Extension para traducir cualquier String de forma dinámica
extension DynamicTranslation on String {
  /// Traduce el string usando el servicio de traducción dinámico
  String tr(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return TranslationService.translate(this, locale);
  }
}
