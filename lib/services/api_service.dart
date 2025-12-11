import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class TokenFetchException implements Exception {
  final String message;
  TokenFetchException(this.message);
  @override
  String toString() => 'TokenFetchException: $message';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final AppConfig _config = AppConfig();

  String get baseUrl => _config.backendUrl;

  Future<String> getToken(
    String roomName,
    String username,
  ) async {
    return getTokenWithServerUrl(roomName, username, _config.backendUrl);
  }

  Future<String> getTokenWithServerUrl(
    String roomName,
    String username,
    String serverUrl,
  ) async {
    if (roomName.isEmpty || username.isEmpty) {
      throw TokenFetchException('Room name and username are required');
    }

    final url = Uri.parse('$serverUrl/api/token');
    final requestBody = jsonEncode({
      'roomName': roomName,
      'username': username,
    });

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final token = responseData['token'] as String?;
        if (token == null || token.isEmpty) {
          throw TokenFetchException('Invalid response: token is missing');
        }
        return token;
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        throw TokenFetchException(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      } else {
        throw NetworkException(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } on FormatException catch (e) {
      throw TokenFetchException('Invalid response format: ${e.message}');
    } catch (e) {
      if (e is TokenFetchException || e is NetworkException) {
        rethrow;
      }
      throw NetworkException('Unexpected error: $e');
    }
  }
}

