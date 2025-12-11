import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user.dart';

class AuthService {
  final AppConfig _config = AppConfig();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<User?> getCurrentUser() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson == null) return null;
    return User.fromJson(jsonDecode(userJson));
  }

  Future<void> _saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> _saveUser(User user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<AuthResult> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${_config.backendUrl}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String;
        final user = User.fromJson(data['user'] as Map<String, dynamic>);

        await _saveToken(token);
        await _saveUser(user);

        return AuthResult.success(user);
      } else {
        final error = jsonDecode(response.body)['error'] as String?;
        return AuthResult.failure(error ?? 'Registration failed');
      }
    } catch (e) {
      return AuthResult.failure('Network error: $e');
    }
  }

  Future<AuthResult> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${_config.backendUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String;
        final user = User.fromJson(data['user'] as Map<String, dynamic>);

        await _saveToken(token);
        await _saveUser(user);

        return AuthResult.success(user);
      } else {
        final error = jsonDecode(response.body)['error'] as String?;
        return AuthResult.failure(error ?? 'Login failed');
      }
    } catch (e) {
      return AuthResult.failure('Network error: $e');
    }
  }

  Future<User?> getMe() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${_config.backendUrl}/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data as Map<String, dynamic>);
        await _saveUser(user);
        return user;
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }
}

class AuthResult {
  final bool success;
  final User? user;
  final String? error;

  AuthResult.success(this.user)
      : success = true,
        error = null;

  AuthResult.failure(this.error)
      : success = false,
        user = null;
}

