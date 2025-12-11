import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/scheduled_call.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'livekit_service.dart';

class ScheduledService {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  Future<ScheduledCall> createScheduledCall({
    required CallType callType,
    required DateTime scheduledAt,
    required String timezone,
    required List<String> invitees,
    RecurrencePattern? recurrence,
    required String title,
    String description = '',
    int maxParticipants = 0,
    int maxDurationSeconds = 0,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final recurrenceJson = recurrence != null ? jsonEncode(recurrence.toJson()) : '{"type":"none"}';
      
      // Ensure scheduledAt is in UTC and includes timezone (RFC3339 format)
      final scheduledAtUtc = scheduledAt.toUtc();
      final scheduledAtString = scheduledAtUtc.toIso8601String();
      
      final response = await http.post(
        Uri.parse('${_apiService.baseUrl}/api/calls/scheduled'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'callType': callType == CallType.video ? 'video' : 'voice',
          'scheduledAt': scheduledAtString,
          'timezone': timezone,
          'invitees': invitees,
          'recurrence': recurrenceJson,
          'title': title,
          'description': description,
          'maxParticipants': maxParticipants,
          'maxDurationSeconds': maxDurationSeconds,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ScheduledCall.fromJson(data as Map<String, dynamic>);
      } else {
        final error = jsonDecode(response.body)['error'] as String?;
        throw Exception(error ?? 'Failed to create scheduled call');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<ScheduledCall>> getScheduledCalls({String? status}) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      var uri = Uri.parse('${_apiService.baseUrl}/api/calls/scheduled/list');
      if (status != null) {
        uri = uri.replace(queryParameters: {'status': status});
      }

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

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
                return ScheduledCall.fromJson(json as Map<String, dynamic>);
              } catch (e) {
                debugPrint('Error parsing scheduled call item: $e');
                return null;
              }
            })
            .whereType<ScheduledCall>()
            .toList();
      } else {
        throw Exception('Failed to get scheduled calls: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<ScheduledCall> getScheduledCallDetails(int id) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.get(
        Uri.parse('${_apiService.baseUrl}/api/calls/scheduled/details?id=$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScheduledCall.fromJson(data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get scheduled call details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> updateScheduledCall(int id, Map<String, dynamic> updates) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.put(
        Uri.parse('${_apiService.baseUrl}/api/calls/scheduled/update?id=$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to update scheduled call: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> cancelScheduledCall(int id) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.delete(
        Uri.parse('${_apiService.baseUrl}/api/calls/scheduled/cancel?id=$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to cancel scheduled call: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> startScheduledCall(int id) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.post(
        Uri.parse('${_apiService.baseUrl}/api/calls/scheduled/start?id=$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to start scheduled call: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

