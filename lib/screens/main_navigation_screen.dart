import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/invitation.dart';
import '../services/websocket_service.dart';
import 'call_history_screen.dart';
import 'contacts_list_screen.dart';
import 'incoming_call_screen.dart';
import 'profile_screen.dart';
import 'scheduled_calls_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  StreamSubscription<Invitation>? _invitationSubscription;
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ContactsListScreen(),
    const CallHistoryScreen(),
    const ScheduledCallsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
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

  void _setupWebSocket() {
    final wsService = context.read<WebSocketService>();
    _invitationSubscription?.cancel();
    _invitationSubscription = wsService.invitationStream.listen(
      (invitation) {
        debugPrint(
          'MainNavigation: Received invitation in stream: ${invitation.id}',
        );
        if (mounted) {
          debugPrint(
            'MainNavigation: Widget is mounted, showing incoming call dialog',
          );
          _showIncomingCall(invitation);
        } else {
          debugPrint('MainNavigation: Widget is not mounted, cannot show dialog');
        }
      },
      onError: (error) {
        debugPrint('MainNavigation: Error in invitation stream: $error');
      },
    );
  }

  @override
  void dispose() {
    _invitationSubscription?.cancel();
    super.dispose();
  }

  void _showIncomingCall(Invitation invitation) {
    debugPrint(
      'MainNavigation: _showIncomingCall called for invitation ${invitation.id}',
    );

    if (!mounted) {
      debugPrint('MainNavigation: Widget not mounted, cannot show dialog');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => IncomingCallScreen(invitation: invitation),
    );
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _ModernBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

class _ModernBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _ModernBottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.contacts,
                label: 'Contacts',
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
                index: 0,
                currentIndex: currentIndex,
              ),
              _NavItem(
                icon: Icons.history,
                label: 'History',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
                index: 1,
                currentIndex: currentIndex,
              ),
              _NavItem(
                icon: Icons.calendar_today,
                label: 'Meetings',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
                index: 2,
                currentIndex: currentIndex,
              ),
              _NavItem(
                icon: Icons.person,
                label: 'Profile',
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
                index: 3,
                currentIndex: currentIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int index;
  final int currentIndex;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.index,
    required this.currentIndex,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return Expanded(
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _scaleAnimation.value, child: child);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child:
                    AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFF8B5CF6),
                                    ],
                                  )
                                : null,
                            color: isSelected ? null : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            color: isSelected ? Colors.white : Colors.grey[600],
                            size: isSelected ? 24 : 22,
                          ),
                        )
                        .animate(target: isSelected ? 1 : 0)
                        .scale(
                          duration: 300.ms,
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.1, 1.1),
                        ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    fontSize: isSelected ? 11 : 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : Colors.grey[600]!,
                  ),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
