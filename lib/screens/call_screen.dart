import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';
import '../services/livekit_service.dart';
import '../services/websocket_service.dart';
import '../services/invitation_service.dart';
import '../widgets/call_top_bar.dart';
import '../widgets/call_controls_bar.dart';
import '../widgets/participant_tile.dart';

class CallScreen extends StatefulWidget {
  final String roomName;
  final String userName;
  final CallType callType;
  final String callId;

  const CallScreen({
    super.key,
    required this.roomName,
    required this.userName,
    required this.callType,
    required this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  StreamSubscription? _callEndedSubscription;
  StreamSubscription? _responseSubscription;
  final InvitationService _invitationService = InvitationService();

  @override
  void initState() {
    super.initState();
    _setupCallEndedListener();
  }

  void _setupCallEndedListener() {
    final wsService = context.read<WebSocketService>();
    _callEndedSubscription = wsService.callEndedStream.listen((callEnded) {
      if (mounted) {
        _handleEndCall(null, immediate: true);
      }
    });

    _responseSubscription = wsService.responseStream.listen((response) {
      if (mounted && !response.accepted) {
        _handleEndCall(null, immediate: true);
      }
    });
  }

  @override
  void dispose() {
    _callEndedSubscription?.cancel();
    _responseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleEndCall(
    LiveKitService? liveKitService, {
    bool immediate = false,
  }) async {
    // Only call backend API if not immediate (immediate means we received WebSocket event)
    // This prevents double-calling when the other participant ends the call
    if (!immediate && widget.callId.isNotEmpty) {
      try {
        await _invitationService.endCall(widget.callId);
      } catch (e) {
        // Log error but continue with disconnect
        debugPrint('Failed to end call via API: $e');
      }
    }

    if (liveKitService != null) {
      await liveKitService.disconnect();
    }
    if (mounted) {
      if (immediate) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LiveKitService>(
      builder: (context, liveKitService, child) {
        final remoteParticipants = liveKitService.remoteParticipants;
        final localParticipant = liveKitService.room?.localParticipant;
        final totalParticipants =
            remoteParticipants.length + (localParticipant != null ? 1 : 0);

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            top: false,
            bottom: false,
            child: Stack(
              children: [
                if (widget.callType == CallType.voice)
                  _buildVoiceCallView(
                    remoteParticipants,
                    localParticipant,
                    liveKitService,
                  )
                else
                  _buildVideoCallView(
                    remoteParticipants,
                    localParticipant,
                    liveKitService,
                    totalParticipants,
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child:
                          CallTopBar(
                                liveKitService: liveKitService,
                                participantCount:
                                    remoteParticipants.length +
                                    (localParticipant != null ? 1 : 0),
                                roomName: widget.roomName,
                                onBack: () => _handleEndCall(liveKitService),
                              )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: -1, end: 0),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child:
                          CallControlsBar(
                                liveKitService: liveKitService,
                                callType: widget.callType,
                                onEndCall: () => _handleEndCall(liveKitService),
                              )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 1, end: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoiceCallView(
    List<lk.RemoteParticipant> remoteParticipants,
    lk.LocalParticipant? localParticipant,
    LiveKitService liveKitService,
  ) {
    final allParticipants = <lk.Participant>[];
    allParticipants.addAll(remoteParticipants);
    if (localParticipant != null) {
      allParticipants.add(localParticipant);
    }

    if (allParticipants.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // For voice calls, show first participant or grid if multiple
    if (allParticipants.length == 1) {
      return ParticipantTile(
        participant: allParticipants.first,
        isLocal: allParticipants.first is lk.LocalParticipant,
        callType: CallType.voice,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Multiple participants - use grid
    return _buildParticipantGrid(allParticipants, CallType.voice);
  }

  Widget _buildVideoCallView(
    List<lk.RemoteParticipant> remoteParticipants,
    lk.LocalParticipant? localParticipant,
    LiveKitService liveKitService,
    int totalParticipants,
  ) {
    final allParticipants = <lk.Participant>[];
    allParticipants.addAll(remoteParticipants);
    if (localParticipant != null) {
      allParticipants.add(localParticipant);
    }

    if (allParticipants.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // For 2 participants: full-screen remote + small local (WhatsApp style)
    if (totalParticipants == 2 &&
        remoteParticipants.isNotEmpty &&
        localParticipant != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ParticipantTile(
            participant: remoteParticipants.first as lk.Participant,
            isLocal: false,
            callType: CallType.video,
            width: double.infinity,
            height: double.infinity,
          ),
          Positioned(
            bottom:
                120, // Increased from 100 to avoid overlap with controls bar
            right: 16,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ParticipantTile(
                  participant: localParticipant as lk.Participant,
                  isLocal: true,
                  callType: CallType.video,
                  width: 120,
                  height: 160,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // For 3+ participants: use grid layout
    return _buildParticipantGrid(allParticipants, CallType.video);
  }

  Widget _buildParticipantGrid(
    List<lk.Participant> participants,
    CallType callType,
  ) {
    if (participants.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // Determine grid layout based on participant count
    int crossAxisCount;
    if (participants.length <= 2) {
      crossAxisCount = 1;
    } else if (participants.length <= 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final isLocal = participant is lk.LocalParticipant;
        return ParticipantTile(
          participant: participant,
          isLocal: isLocal,
          callType: callType,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }
}
