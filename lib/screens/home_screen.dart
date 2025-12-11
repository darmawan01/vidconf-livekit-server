import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/invitation_service.dart';
import '../services/websocket_service.dart';
import '../services/livekit_service.dart';
import '../models/invitation.dart';
import '../widgets/modern_button.dart';
import 'contacts_screen.dart';
import 'invite_contacts_screen.dart';
import 'incoming_call_screen.dart';
import 'call_history_screen.dart';
import 'scheduled_calls_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final InvitationService _invitationService = InvitationService();
  List<Invitation> _pendingInvitations = [];
  String? _currentUsername;
  StreamSubscription<Invitation>? _invitationSubscription;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadPendingInvitations();
    _setupWebSocket();
    _ensureWebSocketConnected();
  }

  Future<void> _ensureWebSocketConnected() async {
    final wsService = context.read<WebSocketService>();
    if (!wsService.isConnected) {
      try {
        await wsService.connect();
      } catch (e) {
        debugPrint('Failed to connect WebSocket: $e');
      }
    }
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUsername = user?.username;
    });
  }

  Future<void> _loadPendingInvitations() async {
    try {
      final invitations = await _invitationService.getPendingInvitations();
      setState(() {
        _pendingInvitations = invitations;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  void _setupWebSocket() {
    final wsService = context.read<WebSocketService>();
    _invitationSubscription?.cancel();
    _invitationSubscription = wsService.invitationStream.listen(
      (invitation) {
        debugPrint('HomeScreen: Received invitation in stream: ${invitation.id}');
        if (mounted) {
          debugPrint('HomeScreen: Widget is mounted, showing incoming call dialog');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showIncomingCall(invitation);
            }
          });
        } else {
          debugPrint('HomeScreen: Widget is not mounted, cannot show dialog');
        }
      },
      onError: (error) {
        debugPrint('HomeScreen: Error in invitation stream: $error');
      },
    );
  }

  @override
  void dispose() {
    _invitationSubscription?.cancel();
    super.dispose();
  }

  void _showIncomingCall(Invitation invitation) {
    debugPrint('HomeScreen: _showIncomingCall called for invitation ${invitation.id}');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallScreen(invitation: invitation),
    ).then((_) {
      _loadPendingInvitations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: Text('Welcome, ${_currentUsername ?? "User"}'),
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications),
                        onPressed: _loadPendingInvitations,
                        tooltip: 'Pending Invitations',
                      ),
                      if (_pendingInvitations.isNotEmpty)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${_pendingInvitations.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      final wsService = context.read<WebSocketService>();
                      final navigator = Navigator.of(context);
                      await wsService.disconnect();
                      await _authService.logout();
                      if (mounted) {
                        navigator.pushReplacementNamed('/login');
                      }
                    },
                    tooltip: 'Logout',
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_call,
                              size: 110,
                              color: Colors.white,
                            )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .scale(delay: 200.ms, duration: 400.ms),
                        const SizedBox(height: 12),
                        const Text(
                              'Video Conference',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 600.ms)
                            .slideY(begin: -0.2, end: 0),
                        const SizedBox(height: 56),
                        Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ModernButton(
                                      text: 'Contacts',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ContactsScreen(),
                                          ),
                                        );
                                      },
                                      icon: Icons.contacts,
                                      width: double.infinity,
                                    ),
                                    const SizedBox(height: 16),
                                    ModernButton(
                                      text: 'New Call',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const InviteContactsScreen(),
                                          ),
                                        );
                                      },
                                      icon: Icons.video_call,
                                      width: double.infinity,
                                    ),
                                    const SizedBox(height: 16),
                                    ModernButton(
                                      text: 'Call History',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const CallHistoryScreen(),
                                          ),
                                        );
                                      },
                                      icon: Icons.history,
                                      width: double.infinity,
                                    ),
                                    const SizedBox(height: 16),
                                    ModernButton(
                                      text: 'Scheduled Calls',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ScheduledCallsScreen(),
                                          ),
                                        );
                                      },
                                      icon: Icons.calendar_today,
                                      width: double.infinity,
                                    ),
                                    if (_pendingInvitations.isNotEmpty) ...[
                                      const SizedBox(height: 24),
                                      const Divider(),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Pending Invitations',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
                                      ..._pendingInvitations.map((invitation) {
                                        return Card(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: ListTile(
                                            leading: Icon(
                                              invitation.callType ==
                                                      CallType.video
                                                  ? Icons.video_call
                                                  : Icons.phone,
              ),
                                            title: Text(
                                              'From: ${invitation.inviter}',
                                            ),
                                            subtitle: Text(
                                              invitation.callType ==
                                                      CallType.video
                                                  ? 'Video Call'
                                                  : 'Voice Call',
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.check,
                                                    color: Colors.green,
                                                  ),
                                                  onPressed: () async {
                                                    final messenger = ScaffoldMessenger.of(context);
                                                    try {
                                                      final result =
                                                          await _invitationService
                                                              .respondToInvitation(
                                                                invitation.id,
                                                                true,
                                                              );
                                                      if (result != null &&
                                                          mounted) {
                                                        // Navigate to call screen
                                                        // This would require LiveKitService integration
                                                        _loadPendingInvitations();
                                                      }
                                                    } catch (e) {
                                                      if (mounted) {
                                                        messenger.showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error: $e',
                                                            ),
                ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.close,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () async {
                                                    try {
                                                      await _invitationService
                                                          .respondToInvitation(
                                                            invitation.id,
                                                            false,
                                                          );
                                                      if (mounted) {
                                                        _loadPendingInvitations();
                                                      }
                                                    } catch (e) {
                                                      // Ignore
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 500.ms, duration: 600.ms)
                            .slideY(begin: 0.2, end: 0),
                      ],
                    ),
                  ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
