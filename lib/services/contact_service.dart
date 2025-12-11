import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/contact.dart';
import 'auth_service.dart';

class ContactService {
  final AppConfig _config = AppConfig();
  final AuthService _authService = AuthService();

  Future<String?> _getAuthToken() async {
    return await _authService.getToken();
  }

  Future<List<Contact>> getContacts() async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.get(
        Uri.parse('${_config.backendUrl}/api/contacts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Contact.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get contacts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> addContact(String username) async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.post(
        Uri.parse('${_config.backendUrl}/api/contacts/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'username': username}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 201) {
        final error = jsonDecode(response.body)['error'] as String?;
        throw Exception(error ?? 'Failed to add contact');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> removeContact(int contactId) async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.delete(
        Uri.parse('${_config.backendUrl}/api/contacts/remove?contactId=$contactId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body)['error'] as String?;
        throw Exception(error ?? 'Failed to remove contact');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<Contact>> searchContacts(String query) async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.get(
        Uri.parse('${_config.backendUrl}/api/contacts/search?q=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Contact.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to search contacts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

