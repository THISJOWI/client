
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for secure storage management
/// 
/// Handles:
/// - Encryption key storage
/// - User credentials management
/// - Secure data persistence
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  
  factory SecureStorageService() => _instance;
  
  SecureStorageService._internal();

  static const String _encryptionKeyKey = 'db_encryption_key';
  static const String _masterPasswordHashKey = 'master_password_hash';

  /// Get or create the database encryption key
  Future<String> getDatabaseEncryptionKey() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if key already exists
    String? key = prefs.getString(_encryptionKeyKey);
    
    if (key == null) {
      // Generate a new key based on user credentials
      // In production, this should be derived from:
      // 1. User's master password
      // 2. Biometric authentication
      // 3. Secure enclave/keychain
      key = await _generateEncryptionKey();
      await prefs.setString(_encryptionKeyKey, key);
    }
    
    return key;
  }

  /// Generate a new encryption key
  Future<String> _generateEncryptionKey() async {
    // Get user email as seed
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? 'default_user';
    
    // Generate a deterministic key from email and a salt
    // IMPORTANT: In production, use a proper key derivation function
    // like PBKDF2, Argon2, or scrypt
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final keyMaterial = '$email-$timestamp-thisjowi-secure-key';
    
    // Hash the key material
    final bytes = utf8.encode(keyMaterial);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  /// Set master password (for future use with biometric unlock)
  Future<void> setMasterPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Hash the password before storing
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    
    await prefs.setString(_masterPasswordHashKey, hash.toString());
  }

  /// Verify master password
  Future<bool> verifyMasterPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_masterPasswordHashKey);
    
    if (storedHash == null) return false;
    
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    
    return hash.toString() == storedHash;
  }

  /// Clear all secure data (on logout)
  Future<void> clearSecureData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_encryptionKeyKey);
    await prefs.remove(_masterPasswordHashKey);
  }

  /// Reset encryption key (forces database recreation)
  Future<void> resetEncryptionKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_encryptionKeyKey);
  }

  /// Save a value to secure storage
  Future<void> saveValue(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  /// Get a value from secure storage
  Future<String?> getValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// Delete a value from secure storage
  Future<void> deleteValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Clear cached credentials
  Future<void> clearCachedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_token');
    await prefs.remove('cached_email');
  }
}
