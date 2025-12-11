import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import 'auth_service.dart';
import '../data/models/otp_entry.dart';

/// Service to connect with the OTP API.
class OtpApiService {
  String get baseUrl => ApiConfig.otpUrl;
  final AuthService _authService;

  OtpApiService(this._authService);

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

  dynamic _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  /// Fetch all OTP entries
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
          return {'success': true, 'data': entries, 'message': 'OTP entries retrieved successfully'};
        }
        return {'success': true, 'data': <OtpEntry>[], 'message': 'No entries found'};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.', 'data': <OtpEntry>[]};
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.', 'data': <OtpEntry>[]};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.', 'data': <OtpEntry>[]};
      }

      return {
        'success': false,
        'message': body?['message'] ?? 'Error: ${res.statusCode}',
        'data': <OtpEntry>[]
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Connection timeout. Please try again.',
        'data': <OtpEntry>[]
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch OTP entries: $e',
        'data': <OtpEntry>[]
      };
    }
  }

  /// Create a new OTP entry
  Future<Map<String, dynamic>> createOtpEntry(OtpEntry entry) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(baseUrl);
      
      final entryData = {
        'name': entry.name,
        'issuer': entry.issuer,
        'secret': entry.secret,
        'digits': entry.digits,
        'period': entry.period,
        'algorithm': entry.algorithm,
        'type': entry.type,
      };

      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(entryData),
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final createdEntry = OtpEntry.fromJson(body);
        return {'success': true, 'data': createdEntry};
      } else {
        return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Failed to create OTP entry: $e'};
    }
  }

  /// Update an OTP entry
  Future<Map<String, dynamic>> updateOtpEntry(String id, OtpEntry entry) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/$id');
      
      final entryData = {
        'name': entry.name,
        'issuer': entry.issuer,
        'secret': entry.secret,
        'digits': entry.digits,
        'period': entry.period,
        'algorithm': entry.algorithm,
        'type': entry.type,
      };

      final res = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(entryData),
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200) {
        final updatedEntry = OtpEntry.fromJson(body);
        return {'success': true, 'data': updatedEntry};
      } else {
        return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Failed to update OTP entry: $e'};
    }
  }

  /// Delete an OTP entry
  Future<Map<String, dynamic>> deleteOtpEntry(String id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/$id');
      
      final res = await http.delete(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200 || res.statusCode == 204) {
        return {'success': true, 'message': 'Deleted successfully'};
      } else {
        final body = _tryDecode(res.body);
        return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete OTP entry: $e'};
    }
  }
}
