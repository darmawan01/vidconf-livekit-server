import 'dart:convert';
import '../services/livekit_service.dart';

enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly;

  static RecurrenceType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'daily':
        return RecurrenceType.daily;
      case 'weekly':
        return RecurrenceType.weekly;
      case 'monthly':
        return RecurrenceType.monthly;
      default:
        return RecurrenceType.none;
    }
  }
}

enum ScheduledCallStatus {
  scheduled,
  started,
  completed,
  cancelled;

  static ScheduledCallStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'started':
        return ScheduledCallStatus.started;
      case 'completed':
        return ScheduledCallStatus.completed;
      case 'cancelled':
        return ScheduledCallStatus.cancelled;
      default:
        return ScheduledCallStatus.scheduled;
    }
  }
}

class RecurrencePattern {
  final RecurrenceType type;
  final int interval;
  final List<int>? daysOfWeek;
  final DateTime? endDate;
  final int? occurrences;

  RecurrencePattern({
    required this.type,
    this.interval = 1,
    this.daysOfWeek,
    this.endDate,
    this.occurrences,
  });

  factory RecurrencePattern.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return RecurrencePattern(type: RecurrenceType.none);
    }
    return RecurrencePattern(
      type: RecurrenceType.fromString(json['type'] as String? ?? 'none'),
      interval: json['interval'] as int? ?? 1,
      daysOfWeek: json['daysOfWeek'] != null
          ? (json['daysOfWeek'] as List<dynamic>).map((e) => e as int).toList()
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      occurrences: json['occurrences'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'interval': interval,
      'daysOfWeek': daysOfWeek,
      'endDate': endDate?.toIso8601String(),
      'occurrences': occurrences,
    };
  }
}

class ScheduledCall {
  final int id;
  final String callId;
  final String roomName;
  final CallType callType;
  final int createdBy;
  final DateTime scheduledAt;
  final String timezone;
  final RecurrencePattern? recurrence;
  final String title;
  final String description;
  final String joinLink;
  final ScheduledCallStatus status;
  final List<String> invitees;
  final int maxParticipants;
  final int maxDurationSeconds;

  ScheduledCall({
    required this.id,
    required this.callId,
    required this.roomName,
    required this.callType,
    required this.createdBy,
    required this.scheduledAt,
    required this.timezone,
    this.recurrence,
    required this.title,
    required this.description,
    required this.joinLink,
    required this.status,
    required this.invitees,
    this.maxParticipants = 0,
    this.maxDurationSeconds = 0,
  });

  factory ScheduledCall.fromJson(Map<String, dynamic> json) {
    RecurrencePattern? recurrence;
    final recurrenceValue = json['recurrence'];
    if (recurrenceValue != null) {
      if (recurrenceValue is String && recurrenceValue.isNotEmpty) {
        try {
          final decoded = jsonDecode(recurrenceValue) as Map<String, dynamic>;
          recurrence = RecurrencePattern.fromJson(decoded);
        } catch (e) {
          recurrence = null;
        }
      } else if (recurrenceValue is Map) {
        try {
          recurrence = RecurrencePattern.fromJson(recurrenceValue as Map<String, dynamic>);
        } catch (e) {
          recurrence = null;
        }
      }
    }

    List<String> invitees = [];
    final inviteesValue = json['invitees'];
    if (inviteesValue != null) {
      if (inviteesValue is List) {
        invitees = inviteesValue.map((e) => e.toString()).toList();
      } else if (inviteesValue is String) {
        try {
          final decoded = jsonDecode(inviteesValue) as List<dynamic>;
          invitees = decoded.map((e) => e.toString()).toList();
        } catch (e) {
          invitees = [];
        }
      }
    }

    return ScheduledCall(
      id: json['id'] as int? ?? 0,
      callId: json['callId'] as String? ?? '',
      roomName: json['roomName'] as String? ?? '',
      callType: (json['callType'] as String? ?? 'voice') == 'video' ? CallType.video : CallType.voice,
      createdBy: json['createdBy'] as int? ?? 0,
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.parse(json['scheduledAt'] as String)
          : DateTime.now(),
      timezone: json['timezone'] as String? ?? 'UTC',
      recurrence: recurrence,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      joinLink: json['joinLink'] as String? ?? '',
      status: ScheduledCallStatus.fromString(json['status'] as String? ?? 'scheduled'),
      invitees: invitees,
      maxParticipants: json['maxParticipants'] as int? ?? 0,
      maxDurationSeconds: json['maxDurationSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callId': callId,
      'roomName': roomName,
      'callType': callType == CallType.video ? 'video' : 'voice',
      'scheduledAt': scheduledAt.toIso8601String(),
      'timezone': timezone,
      'recurrence': recurrence != null ? jsonEncode(recurrence!.toJson()) : null,
      'title': title,
      'description': description,
      'joinLink': joinLink,
      'status': status.name,
      'invitees': invitees,
      'maxParticipants': maxParticipants,
      'maxDurationSeconds': maxDurationSeconds,
    };
  }
}

