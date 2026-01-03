import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';

/// Simple service to connect with the authentication API.
///
/// Contract:
/// - login(email, password) -> Future<Map> { success: bool, data?: Map, message?: String }
/// - register(email, password) -> Future<Map> { success: bool, data?: Map, message?: String }
/// - changePassword(current, new, confirm) -> Future<Map> { success: bool, message?: String, data?: Map }
/// - deleteAccount() -> Future<Map> { success: bool, message?: String }
/// - getToken() -> Future<String?>
/// - getEmail() -> Future<String?>
/// - logout() -> Future<void>
class AuthService {
  // URL base del servicio de autenticación desde ApiConfig
  String get baseUrl => ApiConfig.authUrl;

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final uri = Uri.parse('$baseUrl/login');
      
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 30));


      final body = _tryDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (body != null && body['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', body['token']);
          await prefs.setString('email', email);
          return {'success': true, 'data': body};
        }
        return {'success': false, 'message': body?['message'] ?? 'No token returned'};
      }

      return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register(
    String email, 
    String password, {
    String? fullName,
    String? country,
    String? accountType,
    String? hostingMode,
    String? birthdate,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/register');
      final bodyData = {
        'email': email, 
        'password': password,
      };
      
      if (fullName != null) bodyData['fullName'] = fullName;
      if (country != null) bodyData['country'] = country;
      if (accountType != null) bodyData['accountType'] = accountType;
      if (hostingMode != null) bodyData['hostingMode'] = hostingMode;
      if (birthdate != null) bodyData['birthdate'] = birthdate;

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyData),
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'data': body};
      }

  return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUser({
    String? country,
    String? accountType,
    String? hostingMode,
    String? birthdate,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final uri = Uri.parse('$baseUrl/user');
      final bodyData = <String, String>{};
      
      if (country != null) bodyData['country'] = country;
      if (accountType != null) bodyData['accountType'] = accountType;
      if (hostingMode != null) bodyData['hostingMode'] = hostingMode;
      if (birthdate != null) bodyData['birthdate'] = birthdate;

      final res = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyData),
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200) {
        return {'success': true, 'data': body};
      }

      return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('email');
  }

  Future<void> setSession(String token, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('email', email);
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword, String confirmPassword) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final uri = Uri.parse('$baseUrl/change-password');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        }),
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200) {
        return {'success': true, 'data': body};
      }

      return {'success': false, 'message': body?['message'] ?? 'Error changing password: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to change password: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final uri = Uri.parse('$baseUrl/delete-account');
      final res = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200 || res.statusCode == 204) {
        // Clear token after deleting the account
        await logout();
        return {'success': true, 'message': 'Account deleted successfully'};
      }

      final body = _tryDecode(res.body);
      return {'success': false, 'message': body?['message'] ?? 'Error deleting account: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete account: $e'};
    }
  }

  dynamic _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
}
