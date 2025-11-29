import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import '../backend/models/note.dart';
import '../core/api_config.dart';
import 'auth_service.dart';

/// Service to connect with the notes API.
///
/// Contract:
/// - getAllNotes() -> Future<Map> { success: bool, data?: List<Note>, message?: String }
/// - createNote(note) -> Future<Map> { success: bool, data?: Note, message?: String }
/// - updateNote(title, note) -> Future<Map> { success: bool, data?: Note, message?: String }
/// - deleteNote(id) -> Future<Map> { success: bool, message?: String }
/// - searchNotes(title) -> Future<Map> { success: bool, data?: List<Note>, message?: String }
class NotesService {
  String get baseUrl => ApiConfig.notesUrl;
  final AuthService _authService;

  NotesService(this._authService);

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

  /// Get all notes
  Future<Map<String, dynamic>> getAllNotes() async {
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
          final notes = body.map((json) => Note.fromJson(json)).toList();
          return {'success': true, 'data': notes};
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
      return {'success': false, 'message': 'Failed to fetch notes: $e'};
    }
  }

  /// Create a new note
  Future<Map<String, dynamic>> createNote(Note note) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(baseUrl);
      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(note.toJson()),
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (body != null) {
          return {'success': true, 'data': Note.fromJson(body)};
        }
        return {'success': true, 'data': note};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.'};
      } else if (res.statusCode == 400) {
        return {'success': false, 'message': body?['message'] ?? 'Invalid note data'};
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.'};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.'};
      }

      return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to create note: $e'};
    }
  }

  /// Update a note
  Future<Map<String, dynamic>> updateNote(String title, Note note) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/$title');
      final res = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(note.toJson()),
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200) {
        if (body != null) {
          return {'success': true, 'data': Note.fromJson(body)};
        }
        return {'success': true, 'data': note};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.'};
      } else if (res.statusCode == 404) {
        return {'success': false, 'message': 'Note not found'};
      } else if (res.statusCode == 400) {
        return {'success': false, 'message': body?['message'] ?? 'Invalid note data'};
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.'};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.'};
      }

      return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to update note: $e'};
    }
  }

  /// Delete a note by ID
  Future<Map<String, dynamic>> deleteNote(int id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/$id');
      final res = await http.delete(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 204 || res.statusCode == 200) {
        return {'success': true, 'message': 'Note deleted successfully'};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.'};
      } else if (res.statusCode == 404) {
        return {'success': false, 'message': 'Note not found'};
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
      return {'success': false, 'message': 'Failed to delete note: $e'};
    }
  }

  /// Search notes by title
  Future<Map<String, dynamic>> searchNotes(String title) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/search?title=$title');
      final res = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      final body = _tryDecode(res.body);

      if (res.statusCode == 200) {
        if (body is List) {
          final notes = body.map((json) => Note.fromJson(json)).toList();
          return {'success': true, 'data': notes};
        }
        return {'success': true, 'data': []};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid or expired token. Please log in again.'};
      } else if (res.statusCode == 400) {
        return {'success': false, 'message': body?['message'] ?? 'Invalid search query'};
      } else if (res.statusCode == 403) {
        return {'success': false, 'message': 'Access denied.'};
      } else if (res.statusCode == 500) {
        return {'success': false, 'message': 'Server error. Please try again later.'};
      }

      return {'success': false, 'message': body?['message'] ?? 'Error: ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timeout. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to search notes: $e'};
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