import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../services/invitation_service.dart';
import '../services/livekit_service.dart';
import '../services/websocket_service.dart';
import 'call_screen.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String contactName;
  final CallType callType;
  final String roomName;
  final String userName;
  final String callId;

  const OutgoingCallScreen({
    super.key,
    required this.contactName,
    required this.callType,
    required this.roomName,
    required this.userName,
    required this.callId,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  final InvitationService _invitationService = InvitationService();
  Timer? _timeoutTimer;
  StreamSubscription? _responseSubscription;
  bool _isEnding = false;

  @override
  void initState() {
    super.initState();
    _startTimeout();
    _setupResponseListener();
  }

  void _setupResponseListener() {
    final wsService = context.read<WebSocketService>();
    _responseSubscription = wsService.responseStream.listen((response) {
      if (!mounted || _isEnding) return;

      if (!response.accepted) {
        _endCall();
      } else {
        _timeoutTimer?.cancel();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CallScreen(
                roomName: widget.roomName,
                userName: widget.userName,
                callType: widget.callType,
                callId: widget.callId,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _responseSubscription?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isEnding) {
        _endCall();
      }
    });
  }

  void _endCall() async {
    if (_isEnding) return;
    _isEnding = true;
    _timeoutTimer?.cancel();

    // Cancel the call via API to notify the participant
    if (widget.callId.isNotEmpty) {
      try {
        await _invitationService.cancelCall(widget.callId);
      } catch (e) {
        // Log error but continue with disconnect
        debugPrint('Failed to cancel call via API: $e');
      }
    }

    if (!mounted) return;
    final liveKitService = context.read<LiveKitService>();
    liveKitService.disconnect();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == CallType.video;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Icon(
                      isVideo ? Icons.video_call : Icons.phone,
                      size: 80,
                      color: Colors.white,
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .scale(
                    delay: 0.ms,
                    duration: 1000.ms,
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.1, 1.1),
                  )
                  .then()
                  .scale(
                    delay: 0.ms,
                    duration: 1000.ms,
                    begin: const Offset(1.1, 1.1),
                    end: const Offset(1.0, 1.0),
                  ),
              const SizedBox(height: 32),
              Text(
                widget.contactName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                isVideo ? 'Calling...' : 'Calling...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                ),
              ).animate().fadeIn(delay: 300.ms),
              const Spacer(),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 35,
                  ),
                  onPressed: _isEnding ? null : _endCall,
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 1, end: 0),
              const SizedBox(height: 16),
              const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
