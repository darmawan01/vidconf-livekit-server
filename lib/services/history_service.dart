import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/call_history.dart';
import 'api_service.dart';
import 'auth_service.dart';

class HistoryService {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  Future<List<CallHistory>> getCallHistory({
    int limit = 50,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      var uri = Uri.parse('${_apiService.baseUrl}/api/calls/history').replace(
        queryParameters: {
          'limit': limit.toString(),
          'offset': offset.toString(),
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (endDate != null) 'endDate': endDate.toIso8601String(),
        },
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          return [];
        }
        final decoded = jsonDecode(responseBody);
        if (decoded == null) {
          return [];
        }
        if (decoded is! List) {
          throw Exception('Invalid response format: expected list');
        }
        return decoded
            .map((json) {
              try {
                return CallHistory.fromJson(json as Map<String, dynamic>);
              } catch (e) {
                debugPrint('Error parsing call history item: $e');
                return null;
              }
            })
            .whereType<CallHistory>()
            .toList();
      } else {
        throw Exception('Failed to get call history: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting call history: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<CallHistory> getCallDetails(String callId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http
          .get(
            Uri.parse(
              '${_apiService.baseUrl}/api/calls/history/details?callId=$callId',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CallHistory.fromJson(data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get call details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> deleteCallHistory(String callId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http
          .delete(
            Uri.parse(
              '${_apiService.baseUrl}/api/calls/history/delete?callId=$callId',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to delete call history: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
