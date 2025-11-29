import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import 'auth_service.dart';
import 'credential_sharing_service.dart';

/// Service to connect with the passwords API.
///
/// Contract:
/// - fetchPasswords() -> Future<Map> { success: bool, data?: List, message?: String }
/// - addPassword(data) -> Future<Map> { success: bool, message?: String }
/// - updatePassword(id, data) -> Future<Map> { success: bool, message?: String }
/// - deletePassword(id) -> Future<Map> { success: bool, message?: String }
class PasswordService {
  String get baseUrl => ApiConfig.passwordsUrl;
  final AuthService authService = AuthService();
  final CredentialSharingService _credentialService = CredentialSharingService();

  Future<Map<String, String>?> _getAuthHeaders() async {
    final token = await authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  /// Fetch all passwords
  Future<Map<String, dynamic>> fetchPasswords() async {
    try {
      final headers = await _getAuthHeaders();
      final uri = Uri.parse(baseUrl);
      final res = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200) {
        final data = body ?? [];
        return {
          'success': true,
          'data': data,
          'message': 'Passwords retrieved successfully'
        };
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.', 'data': []};
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.', 'data': []};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.', 'data': []};
      }

      return {
        'success': false,
        'message': body?['message'] ?? 'Error: ${res.statusCode}',
        'data': []
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Connection timeout. Please try again.',
        'data': []
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch passwords: $e',
        'data': []
      };
    }
  }

  /// Add a new password
  Future<Map<String, dynamic>> addPassword(Map<String, dynamic> passwordData) async {
    try {
      if (passwordData.isEmpty) {
        return {'success': false, 'message': 'Password data cannot be empty'};
      }

      final headers = await _getAuthHeaders();
      final uri = Uri.parse(baseUrl);
      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(passwordData),
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        // Sync with iOS AutoFill after adding password
        _syncPasswordsWithAutofill();
        return {'success': true, 'message': 'Password added successfully'};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.'};
      } else if (res.statusCode == 400) {
        return {
          'success': false,
          'message': body?['message'] ?? 'Invalid password data. Ensure all required fields are filled correctly.'
        };
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.'};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.'};
      }

      return {
        'success': false,
        'message': body?['message'] ?? 'Error: ${res.statusCode}'
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to add password: $e'};
    }
  }

  /// Update a password
  Future<Map<String, dynamic>> updatePassword(
    String id,
    Map<String, dynamic> passwordData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final uri = Uri.parse('$baseUrl/$id');
      final res = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(passwordData),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 204 || res.statusCode == 200) {
        // Sync with iOS AutoFill after updating password
        _syncPasswordsWithAutofill();
        return {'success': true, 'message': 'Password updated successfully'};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.'};
      } else if (res.statusCode == 404) {
        return {'success': false, 'message': 'Password not found'};
      } else if (res.statusCode == 400) {
        final body = _tryDecode(res.body);
        return {'success': false, 'message': body?['message'] ?? 'Invalid password data'};
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.'};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.'};
      }

      final body = _tryDecode(res.body);
      return {
        'success': false,
        'message': body?['message'] ?? 'Error: ${res.statusCode}'
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to update password: $e'};
    }
  }

  /// Delete a password
  Future<Map<String, dynamic>> deletePassword(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final uri = Uri.parse('$baseUrl/$id');
      final res = await http.delete(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 204 || res.statusCode == 200) {
        // Sync with iOS AutoFill after deleting password
        _syncPasswordsWithAutofill();
        return {'success': true, 'message': 'Password deleted successfully'};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.'};
      } else if (res.statusCode == 404) {
        return {'success': false, 'message': 'Password not found'};
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.'};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.'};
      }

      final body = _tryDecode(res.body);
      return {
        'success': false,
        'message': body?['message'] ?? 'Error: ${res.statusCode}'
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete password: $e'};
    }
  }

  /// Sync passwords with iOS AutoFill extension
  /// This is called automatically after add/update/delete operations
  Future<void> _syncPasswordsWithAutofill() async {
    try {
      final result = await fetchPasswords();
      if (result['success'] == true && result['data'] != null) {
        final passwords = (result['data'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        
        await _credentialService.syncPasswordsToSharedStorage(passwords);
        await _credentialService.registerCredentialIdentities(passwords);
      }
    } catch (e) {
      // Silently fail - autofill sync is not critical
      print('Failed to sync with autofill: $e');
    }
  }

  /// Manually sync all passwords with autofill services
  /// Call this after login or when needed
  Future<void> syncWithAutofill() async {
    await _syncPasswordsWithAutofill();
  }
}