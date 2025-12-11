import '../services/livekit_service.dart';

enum InvitationStatus {
  pending,
  accepted,
  rejected,
  cancelled;

  static InvitationStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return InvitationStatus.pending;
      case 'accepted':
        return InvitationStatus.accepted;
      case 'rejected':
        return InvitationStatus.rejected;
      case 'cancelled':
        return InvitationStatus.cancelled;
      default:
        return InvitationStatus.pending;
    }
  }
}

class Invitation {
  final int id;
  final String callId;
  final String inviter;
  final String invitee;
  final CallType callType;
  final String roomName;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  Invitation({
    required this.id,
    required this.callId,
    required this.inviter,
    required this.invitee,
    required this.callType,
    required this.roomName,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'] as int,
      callId: json['callId'] as String,
      inviter: json['inviter'] as String,
      invitee: json['invitee'] as String,
      callType: json['callType'] == 'video' ? CallType.video : CallType.voice,
      roomName: json['roomName'] as String,
      status: InvitationStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callId': callId,
      'inviter': inviter,
      'invitee': invitee,
      'callType': callType == CallType.video ? 'video' : 'voice',
      'roomName': roomName,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }
}

