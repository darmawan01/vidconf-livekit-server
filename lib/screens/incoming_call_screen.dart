import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:vidconf/config/app_config.dart';
import '../models/invitation.dart';
import '../services/invitation_service.dart';
import '../services/livekit_service.dart';
import '../services/websocket_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final Invitation invitation;

  const IncomingCallScreen({super.key, required this.invitation});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final InvitationService _invitationService = InvitationService();
  Timer? _timeoutTimer;
  bool _isResponding = false;
  StreamSubscription? _callEndedSubscription;
  StreamSubscription? _responseSubscription;
  StreamSubscription? _callCancelledSubscription;

  @override
  void initState() {
    super.initState();
    _startTimeout();
    _setupCallEndedListener();
  }

  void _setupCallEndedListener() {
    final wsService = context.read<WebSocketService>();
    _callEndedSubscription = wsService.callEndedStream.listen((callEnded) {
      if (mounted && !_isResponding) {
        _timeoutTimer?.cancel();
        Navigator.of(context).pop();
      }
    });

    _responseSubscription = wsService.responseStream.listen((response) {
      if (mounted && !_isResponding && !response.accepted) {
        _timeoutTimer?.cancel();
        Navigator.of(context).pop();
      }
    });

    _callCancelledSubscription = wsService.callCancelledStream.listen((
      callCancelled,
    ) {
      if (mounted &&
          !_isResponding &&
          callCancelled.callId == widget.invitation.callId) {
        _timeoutTimer?.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _callEndedSubscription?.cancel();
    _responseSubscription?.cancel();
    _callCancelledSubscription?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isResponding) {
        _rejectCall();
      }
    });
  }

  Future<void> _acceptCall() async {
    if (_isResponding) return;

    setState(() {
      _isResponding = true;
    });

    _timeoutTimer?.cancel();

    try {
      final result = await _invitationService.respondToInvitation(
        widget.invitation.id,
        true,
      );

      if (result == null) {
        throw Exception('Failed to accept invitation');
      }

      if (!mounted) return;

      final liveKitService = context.read<LiveKitService>();
      await liveKitService.connect(
        AppConfig().liveKitUrl,
        result.token,
        widget.invitation.callType,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CallScreen(
              roomName: result.roomName,
              userName: widget.invitation.invitee,
              callType: widget.invitation.callType,
              callId: widget.invitation.callId,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isResponding = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to accept call: $e')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _rejectCall() async {
    if (_isResponding) return;

    setState(() {
      _isResponding = true;
    });

    _timeoutTimer?.cancel();

    try {
      await _invitationService.respondToInvitation(widget.invitation.id, false);
    } catch (e) {
      // Ignore errors when rejecting
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.invitation.callType == CallType.video;

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
                widget.invitation.inviter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                ),
              ).animate().fadeIn(delay: 300.ms),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
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
                          onPressed: _isResponding ? null : _rejectCall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Reject',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.call,
                            color: Colors.white,
                            size: 35,
                          ),
                          onPressed: _isResponding ? null : _acceptCall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Accept',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 1, end: 0),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
