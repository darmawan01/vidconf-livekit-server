import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/invitation.dart';
import '../services/livekit_service.dart';
import 'auth_service.dart';

class InvitationService {
  final AppConfig _config = AppConfig();
  final AuthService _authService = AuthService();

  Future<String?> _getAuthToken() async {
    return await _authService.getToken();
  }

  Future<CreateCallResult> createCallAndInvite(
    CallType callType,
    List<String> invitees, {
    String? roomName,
  }) async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.post(
        Uri.parse('${_config.backendUrl}/api/calls/invite'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'callType': callType == CallType.video ? 'video' : 'voice',
          'invitees': invitees,
          if (roomName != null) 'roomName': roomName,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return CreateCallResult(
          callId: data['callId'] as String,
          roomName: data['roomName'] as String,
          token: data['token'] as String,
        );
      } else {
        final error = jsonDecode(response.body)['error'] as String?;
        throw Exception(error ?? 'Failed to create call');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<Invitation>> getPendingInvitations() async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.get(
        Uri.parse('${_config.backendUrl}/api/calls/invitations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Invitation.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get invitations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<RespondInvitationResult?> respondToInvitation(
    int invitationId,
    bool accept,
  ) async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.post(
        Uri.parse('${_config.backendUrl}/api/calls/invitations/respond?invitationId=$invitationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'action': accept ? 'accept' : 'reject',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          return RespondInvitationResult(
            token: data['token'] as String,
            roomName: data['roomName'] as String,
          );
        }
        return null;
      } else {
        final error = jsonDecode(response.body)['error'] as String?;
        throw Exception(error ?? 'Failed to respond to invitation');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> endCall(String callId) async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.post(
        Uri.parse('${_config.backendUrl}/api/calls/end?callId=$callId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body)['error'] as String?;
        throw Exception(error ?? 'Failed to end call');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> cancelCall(String callId) async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.post(
        Uri.parse('${_config.backendUrl}/api/calls/cancel?callId=$callId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body)['error'] as String?;
        throw Exception(error ?? 'Failed to cancel call');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

class CreateCallResult {
  final String callId;
  final String roomName;
  final String token;

  CreateCallResult({
    required this.callId,
    required this.roomName,
    required this.token,
  });
}

class RespondInvitationResult {
  final String token;
  final String roomName;

  RespondInvitationResult({
    required this.token,
    required this.roomName,
  });
}

