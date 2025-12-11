import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/invitation.dart';
import '../models/scheduled_call.dart';
import '../services/livekit_service.dart';
import 'auth_service.dart';

class WebSocketService {
  final AppConfig _config = AppConfig();
  final AuthService _authService = AuthService();
  WebSocketChannel? _channel;
  StreamController<Invitation>? _invitationController;
  StreamController<InvitationResponse>? _responseController;
  StreamController<CallEnded>? _callEndedController;
  StreamController<CallCancelled>? _callCancelledController;
  StreamController<ScheduledCall>? _scheduledCallController;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  Stream<Invitation> get invitationStream =>
      _invitationController?.stream ?? const Stream.empty();
  Stream<InvitationResponse> get responseStream =>
      _responseController?.stream ?? const Stream.empty();
  Stream<CallEnded> get callEndedStream =>
      _callEndedController?.stream ?? const Stream.empty();
  Stream<CallCancelled> get callCancelledStream =>
      _callCancelledController?.stream ?? const Stream.empty();
  Stream<ScheduledCall> get scheduledCallStream =>
      _scheduledCallController?.stream ?? const Stream.empty();

  bool get isConnected => _isConnected;

  WebSocketService() {
    _invitationController = StreamController<Invitation>.broadcast();
    _responseController = StreamController<InvitationResponse>.broadcast();
    _callEndedController = StreamController<CallEnded>.broadcast();
    _callCancelledController = StreamController<CallCancelled>.broadcast();
    _scheduledCallController = StreamController<ScheduledCall>.broadcast();
  }

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final wsUrl = _config.backendUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws'));

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      await _authenticate(token);
      _isConnected = true;
      _startPingTimer();
    } catch (e) {
      _isConnected = false;
      _scheduleReconnect();
      rethrow;
    }
  }

  Future<void> _authenticate(String token) async {
    final message = jsonEncode({'type': 'authenticate', 'token': token});
    _channel?.sink.add(message);
  }

  void _handleMessage(dynamic message) {
    try {
      if (kDebugMode) {
        debugPrint('WebSocket received message: $message');
      }
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String;
      if (kDebugMode) {
        debugPrint('WebSocket message type: $type');
      }

      switch (type) {
        case 'authenticated':
          _isConnected = true;
          if (kDebugMode) {
            debugPrint('WebSocket authenticated');
          }
          break;
        case 'call_invitation':
          if (kDebugMode) {
            debugPrint('Received call_invitation');
          }
          final invitationData = data['data'] as Map<String, dynamic>;
          if (kDebugMode) {
            debugPrint('Invitation data: $invitationData');
          }
          // WebSocket sends different format, create Invitation manually
          final invitation = Invitation(
            id: invitationData['invitationId'] as int,
            callId: invitationData['callId'] as String,
            inviter: invitationData['inviter'] as String,
            invitee: '', // Current user is the invitee
            callType: invitationData['callType'] == 'video'
                ? CallType.video
                : CallType.voice,
            roomName: invitationData['roomName'] as String,
            status: InvitationStatus.pending,
            createdAt: DateTime.parse(invitationData['timestamp'] as String),
          );
          if (kDebugMode) {
            debugPrint('Adding invitation to stream: ${invitation.id}');
          }
          _invitationController?.add(invitation);
          break;
        case 'invitation_accepted':
        case 'invitation_rejected':
          final responseData = data['data'] as Map<String, dynamic>;
          final response = InvitationResponse.fromJson(
            responseData,
            type == 'invitation_accepted',
          );
          _responseController?.add(response);
          break;
        case 'call_ended':
          final callData = data['data'] as Map<String, dynamic>;
          final callEnded = CallEnded.fromJson(callData);
          _callEndedController?.add(callEnded);
          break;
        case 'call_cancelled':
          final callData = data['data'] as Map<String, dynamic>;
          final callCancelled = CallCancelled.fromJson(callData);
          _callCancelledController?.add(callCancelled);
          break;
        case 'scheduled_call_created':
          if (kDebugMode) {
            debugPrint('Received scheduled_call_created');
          }
          final scheduledCallData = data['data'] as Map<String, dynamic>;
          try {
            final scheduledCall = ScheduledCall.fromJson(scheduledCallData);
            _scheduledCallController?.add(scheduledCall);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error parsing scheduled call: $e');
            }
          }
          break;
        case 'pong':
          // Ping response, do nothing
          break;
        default:
          if (kDebugMode) {
            debugPrint('Unknown WebSocket message type: $type');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error handling WebSocket message: $e');
      }
    }
  }

  void _handleError(dynamic error) {
    _isConnected = false;
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    _isConnected = false;
    _stopPingTimer();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _stopPingTimer();
    await _channel?.sink.close();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _invitationController?.close();
    _responseController?.close();
    _callEndedController?.close();
    _callCancelledController?.close();
    _scheduledCallController?.close();
  }
}

class InvitationResponse {
  final int invitationId;
  final String invitee;
  final bool accepted;
  final DateTime timestamp;

  InvitationResponse({
    required this.invitationId,
    required this.invitee,
    required this.accepted,
    required this.timestamp,
  });

  factory InvitationResponse.fromJson(
    Map<String, dynamic> json,
    bool accepted,
  ) {
    DateTime timestamp = DateTime.now();
    final timestampValue = json['timestamp'];
    if (timestampValue != null &&
        timestampValue is String &&
        timestampValue.isNotEmpty) {
      try {
        timestamp = DateTime.parse(timestampValue);
      } catch (e) {
        timestamp = DateTime.now();
      }
    }

    return InvitationResponse(
      invitationId: json['invitationId'] as int,
      invitee: json['invitee'] as String,
      accepted: accepted,
      timestamp: timestamp,
    );
  }
}

class CallEnded {
  final String callId;
  final DateTime timestamp;

  CallEnded({required this.callId, required this.timestamp});

  factory CallEnded.fromJson(Map<String, dynamic> json) {
    DateTime timestamp = DateTime.now();
    final timestampValue = json['timestamp'];
    if (timestampValue != null &&
        timestampValue is String &&
        timestampValue.isNotEmpty) {
      try {
        timestamp = DateTime.parse(timestampValue);
      } catch (e) {
        timestamp = DateTime.now();
      }
    }

    return CallEnded(callId: json['callId'] as String, timestamp: timestamp);
  }
}

class CallCancelled {
  final String callId;
  final DateTime timestamp;

  CallCancelled({required this.callId, required this.timestamp});

  factory CallCancelled.fromJson(Map<String, dynamic> json) {
    DateTime timestamp = DateTime.now();
    final timestampValue = json['timestamp'];
    if (timestampValue != null &&
        timestampValue is String &&
        timestampValue.isNotEmpty) {
      try {
        timestamp = DateTime.parse(timestampValue);
      } catch (e) {
        timestamp = DateTime.now();
      }
    }

    return CallCancelled(
      callId: json['callId'] as String,
      timestamp: timestamp,
    );
  }
}
