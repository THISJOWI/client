import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import '../backend/models/otp_entry.dart';
import '../core/api_config.dart';
import 'auth_service.dart';

/// Service to connect with the OTP API backend.
///
/// Contract:
/// - getAllOtpEntries() -> Future<Map> { success: bool, data?: List<OtpEntry>, message?: String }
/// - createOtpEntry(entry) -> Future<Map> { success: bool, data?: OtpEntry, message?: String }
/// - updateOtpEntry(id, entry) -> Future<Map> { success: bool, data?: OtpEntry, message?: String }
/// - deleteOtpEntry(id) -> Future<Map> { success: bool, message?: String }
class OtpBackendService {
  String get baseUrl => ApiConfig.otpUrl;
  final AuthService _authService;

  OtpBackendService(this._authService);

  /// Get common headers with authentication token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token available');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get all OTP entries
  Future<Map<String, dynamic>> getAllOtpEntries() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(baseUrl);
      final res = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200) {
        if (body is List) {
          final entries = body.map((json) => OtpEntry.fromJson(json)).toList();
          return {'success': true, 'data': entries};
        }
        return {'success': true, 'data': []};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.'};
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.'};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.'};
      }

      return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch OTP entries: $e'};
    }
  }

  /// Create a new OTP entry
  Future<Map<String, dynamic>> createOtpEntry(Map<String, dynamic> entryData) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(baseUrl);
      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(entryData),
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (body != null) {
          return {'success': true, 'data': OtpEntry.fromJson(body)};
        }
        return {'success': true, 'data': entryData};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.'};
      } else if (res.statusCode == 400) {
        return {'success': false, 'message': body?['message'] ?? 'Invalid OTP entry data'};
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.'};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.'};
      }

      return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to create OTP entry: $e'};
    }
  }

  /// Update an OTP entry
  Future<Map<String, dynamic>> updateOtpEntry(String id, Map<String, dynamic> entryData) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/$id');
      final res = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(entryData),
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200) {
        if (body != null) {
          return {'success': true, 'data': OtpEntry.fromJson(body)};
        }
        return {'success': true, 'data': entryData};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.'};
      } else if (res.statusCode == 404) {
        return {'success': false, 'message': 'OTP entry not found'};
      } else if (res.statusCode == 400) {
        return {'success': false, 'message': body?['message'] ?? 'Invalid OTP entry data'};
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.'};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.'};
      }

      return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to update OTP entry: $e'};
    }
  }

  /// Delete an OTP entry by ID
  Future<Map<String, dynamic>> deleteOtpEntry(String id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/$id');
      final res = await http.delete(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 204 || res.statusCode == 200) {
        return {'success': true, 'message': 'OTP entry deleted successfully'};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.'};
      } else if (res.statusCode == 404) {
        return {'success': false, 'message': 'OTP entry not found'};
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.'};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.'};
      }

      final body = _tryDecode(res.body);
      return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete OTP entry: $e'};
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
