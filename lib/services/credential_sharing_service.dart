import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage credential sharing with the iOS AutoFill extension
/// 
/// This service syncs passwords to the App Group shared storage
/// so the iOS Credential Provider Extension can access them.
class CredentialSharingService {
  static final CredentialSharingService _instance = CredentialSharingService._internal();
  
  // Method channel for iOS native communication
  static const MethodChannel _channel = MethodChannel('com.thisjowi/credentials');
  
  factory CredentialSharingService() => _instance;
  
  CredentialSharingService._internal();

  /// Sync passwords to the shared App Group storage for iOS AutoFill
  /// 
  /// This method should be called whenever passwords are created, updated, or deleted.
  /// The iOS Credential Provider Extension reads from this shared storage.
  Future<bool> syncPasswordsToSharedStorage(List<Map<String, dynamic>> passwords) async {
    if (!Platform.isIOS) {
      // Only needed for iOS
      return true;
    }

    try {
      // Prepare password data for sharing
      // Only include necessary fields for autofill
      final sharedPasswords = passwords.map((password) => {
        'id': password['id']?.toString() ?? '',
        'title': password['title'] ?? '',
        'username': password['username'] ?? '',
        'password': password['password'] ?? '',
        'website': password['website'] ?? '',
      }).toList();

      // Use method channel to write to App Group UserDefaults
      final result = await _channel.invokeMethod<bool>('syncPasswordsToAppGroup', {
        'passwords': jsonEncode(sharedPasswords),
      });

      return result ?? false;
    } catch (e) {
      print('Error syncing passwords to shared storage: $e');
      return false;
    }
  }

  /// Register credential identities with the iOS Credential Store
  /// 
  /// This allows passwords to appear in the QuickType bar above the keyboard.
  Future<bool> registerCredentialIdentities(List<Map<String, dynamic>> passwords) async {
    if (!Platform.isIOS) {
      return true;
    }

    try {
      final credentials = passwords.map((password) => {
        'id': password['id']?.toString() ?? '',
        'username': password['username'] ?? '',
        'website': password['website'] ?? '',
        'title': password['title'] ?? '',
      }).toList();

      final result = await _channel.invokeMethod<bool>('registerCredentialIdentities', {
        'credentials': jsonEncode(credentials),
      });

      return result ?? false;
    } catch (e) {
      print('Error registering credential identities: $e');
      return false;
    }
  }

  /// Remove all registered credential identities
  Future<bool> clearCredentialIdentities() async {
    if (!Platform.isIOS) {
      return true;
    }

    try {
      final result = await _channel.invokeMethod<bool>('clearCredentialIdentities');
      return result ?? false;
    } catch (e) {
      print('Error clearing credential identities: $e');
      return false;
    }
  }
}
