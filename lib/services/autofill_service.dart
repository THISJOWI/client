import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service to manage password autofill functionality
/// 
/// This service provides:
/// - Check if autofill is enabled/supported
/// - Open system autofill settings
/// - Handle autofill requests from other apps
/// - Provide credentials for autofill
class AutofillService {
  static final AutofillService _instance = AutofillService._internal();
  
  static const MethodChannel _channel = MethodChannel('com.thisjowi/autofill');
  
  factory AutofillService() => _instance;
  
  AutofillService._internal();

  /// Check if the device supports autofill (Android 8.0+ or iOS 12+)
  Future<bool> hasAutofillSupport() async {
    if (kIsWeb) return false;
    
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('hasAutofillSupport');
        return result ?? false;
      } catch (e) {
        debugPrint('Error checking autofill support: $e');
        return false;
      }
    } else if (Platform.isIOS) {
      // iOS 12+ supports AutoFill with Credential Provider Extension
      return true;
    }
    
    return false;
  }

  /// Check if THISJOWI is set as the autofill service provider
  Future<bool> isAutofillServiceEnabled() async {
    if (kIsWeb) return false;
    
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('isAutofillServiceEnabled');
        return result ?? false;
      } catch (e) {
        debugPrint('Error checking autofill status: $e');
        return false;
      }
    } else if (Platform.isIOS) {
      // On iOS, we can't programmatically check if our extension is enabled
      // User must check in Settings > Passwords > AutoFill Passwords
      return true; // Assume enabled, user will see if it works
    }
    
    return false;
  }

  /// Open system settings to enable THISJOWI as autofill provider
  Future<void> openAutofillSettings() async {
    if (kIsWeb) return;
    
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('openAutofillSettings');
      } catch (e) {
        debugPrint('Error opening autofill settings: $e');
      }
    } else if (Platform.isIOS) {
      // On iOS, we can't directly open password settings
      // We can only guide the user
      debugPrint('iOS: User must go to Settings > Passwords > AutoFill Passwords');
    }
  }

  /// Get pending autofill request data (when app is opened from autofill)
  Future<AutofillRequest?> getPendingAutofillRequest() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getPendingAutofillRequest');
      
      if (result != null && result['package'] != null) {
        return AutofillRequest(
          targetPackage: result['package'] as String,
          isSaveRequest: result['isSaveRequest'] as bool? ?? false,
          username: result['username'] as String?,
          password: result['password'] as String?,
        );
      }
    } catch (e) {
      debugPrint('Error getting pending autofill request: $e');
    }
    
    return null;
  }

  /// Provide credentials for an autofill request
  Future<bool> provideAutofillCredentials({
    required String username,
    required String password,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('provideAutofillCredentials', {
        'username': username,
        'password': password,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error providing autofill credentials: $e');
      return false;
    }
  }

  /// Get the autofill status message for UI display
  Future<AutofillStatus> getAutofillStatus() async {
    final hasSupport = await hasAutofillSupport();
    
    if (!hasSupport) {
      return AutofillStatus(
        isSupported: false,
        isEnabled: false,
        message: 'Tu dispositivo no soporta autofill de contraseñas',
        actionText: null,
      );
    }
    
    final isEnabled = await isAutofillServiceEnabled();
    
    if (Platform.isAndroid) {
      if (isEnabled) {
        return AutofillStatus(
          isSupported: true,
          isEnabled: true,
          message: 'THISJOWI está configurado como tu gestor de contraseñas',
          actionText: 'Cambiar configuración',
        );
      } else {
        return AutofillStatus(
          isSupported: true,
          isEnabled: false,
          message: 'Activa THISJOWI como tu gestor de contraseñas para autorellenar en otras apps',
          actionText: 'Activar autofill',
        );
      }
    } else if (Platform.isIOS) {
      return AutofillStatus(
        isSupported: true,
        isEnabled: true, // We can't check on iOS
        message: 'Para usar autofill, ve a Ajustes > Contraseñas > Autorrellenar contraseñas y activa THISJOWI',
        actionText: 'Ver instrucciones',
      );
    }
    
    return AutofillStatus(
      isSupported: false,
      isEnabled: false,
      message: 'Plataforma no soportada',
      actionText: null,
    );
  }
}

/// Represents a pending autofill request from another app
class AutofillRequest {
  final String targetPackage;
  final bool isSaveRequest;
  final String? username;
  final String? password;

  AutofillRequest({
    required this.targetPackage,
    required this.isSaveRequest,
    this.username,
    this.password,
  });

  /// Get a user-friendly name for the target app
  String get appName {
    // Extract app name from package (e.g., "com.twitter.android" -> "Twitter")
    final parts = targetPackage.split('.');
    if (parts.length >= 2) {
      final name = parts[parts.length - 2];
      return name[0].toUpperCase() + name.substring(1);
    }
    return targetPackage;
  }
}

/// Represents the current autofill status
class AutofillStatus {
  final bool isSupported;
  final bool isEnabled;
  final String message;
  final String? actionText;

  AutofillStatus({
    required this.isSupported,
    required this.isEnabled,
    required this.message,
    this.actionText,
  });
}
