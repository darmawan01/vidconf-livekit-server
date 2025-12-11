import 'dart:convert';
import '../services/livekit_service.dart';

enum CallStatus {
  pending,
  completed,
  missed,
  rejected;

  static CallStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return CallStatus.pending;
      case 'completed':
        return CallStatus.completed;
      case 'missed':
        return CallStatus.missed;
      case 'rejected':
        return CallStatus.rejected;
      default:
        return CallStatus.pending;
    }
  }
}

class CallHistory {
  final int id;
  final String callId;
  final String roomName;
  final CallType callType;
  final List<String> participants;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration duration;
  final CallStatus status;

  CallHistory({
    required this.id,
    required this.callId,
    required this.roomName,
    required this.callType,
    required this.participants,
    required this.startedAt,
    this.endedAt,
    required this.duration,
    required this.status,
  });

  factory CallHistory.fromJson(Map<String, dynamic> json) {
    List<String> participants = [];
    final participantsValue = json['participants'];
    if (participantsValue != null) {
      if (participantsValue is String && participantsValue.isNotEmpty) {
        try {
          final decoded = jsonDecode(participantsValue);
          if (decoded is List) {
            participants = decoded.map((e) => e.toString()).toList();
          }
        } catch (e) {
          participants = [];
        }
      } else if (participantsValue is List) {
        participants = participantsValue.map((e) => e.toString()).toList();
      }
    }

    return CallHistory(
      id: json['id'] as int? ?? 0,
      callId: json['callId'] as String? ?? '',
      roomName: json['roomName'] as String? ?? '',
      callType: (json['callType'] as String? ?? 'voice') == 'video' ? CallType.video : CallType.voice,
      participants: participants,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : DateTime.now(),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      duration: Duration(seconds: json['durationSeconds'] as int? ?? 0),
      status: CallStatus.fromString(json['status'] as String? ?? 'completed'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callId': callId,
      'roomName': roomName,
      'callType': callType == CallType.video ? 'video' : 'voice',
      'participants': jsonEncode(participants),
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'status': status.name,
    };
  }
}

