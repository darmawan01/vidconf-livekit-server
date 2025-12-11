import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/scheduled_call.dart';
import '../services/scheduled_service.dart';
import '../services/livekit_service.dart';
import '../services/websocket_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import 'create_scheduled_call_screen.dart';
import 'call_screen.dart';

class ScheduledCallsScreen extends StatefulWidget {
  const ScheduledCallsScreen({super.key});

  @override
  State<ScheduledCallsScreen> createState() => _ScheduledCallsScreenState();
}

class _ScheduledCallsScreenState extends State<ScheduledCallsScreen> {
  final ScheduledService _scheduledService = ScheduledService();
  final AuthService _authService = AuthService();
  List<ScheduledCall> _calls = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _scheduledCallSubscription;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadScheduledCalls();
    _setupWebSocketListener();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
      });
    }
  }

  void _setupWebSocketListener() {
    final wsService = context.read<WebSocketService>();
    _scheduledCallSubscription = wsService.scheduledCallStream.listen(
      (scheduledCall) {
        if (mounted) {
          // Check if call already exists in list
          final exists = _calls.any((c) => c.id == scheduledCall.id);
          if (!exists) {
            setState(() {
              _calls.add(scheduledCall);
              // Sort by scheduled_at
              _calls.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
            });
          }
        }
      },
      onError: (error) {
        if (mounted) {
          debugPrint('Error in scheduled call stream: $error');
        }
      },
    );
  }

  @override
  void dispose() {
    _scheduledCallSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadScheduledCalls() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final calls = await _scheduledService.getScheduledCalls();
      setState(() {
        _calls = calls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelCall(int id) async {
    try {
      await _scheduledService.cancelScheduledCall(id);
      _loadScheduledCalls();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled call cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _joinCall(ScheduledCall call) async {
    // Client-side time validation
    final now = DateTime.now();
    if (call.maxDurationSeconds > 0) {
      final endTime = call.scheduledAt.add(Duration(seconds: call.maxDurationSeconds));
      if (now.isAfter(endTime)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meeting has ended')),
          );
        }
        return;
      }
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final result = await _scheduledService.startScheduledCall(call.id);
      final token = result['token'] as String;
      final roomName = result['roomName'] as String;
      final callId = result['callId'] as String? ?? call.callId;

      // Get current user's username
      final currentUser = await _authService.getCurrentUser();
      final userName = currentUser?.username ?? '';

      if (!mounted) return;
      final liveKitService = context.read<LiveKitService>();
      await liveKitService.connect(
        AppConfig().liveKitUrl,
        token,
        call.callType,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallScreen(
              roomName: roomName,
              userName: userName,
              callType: call.callType,
              callId: callId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining call: $e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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
                title: const Text('Scheduled Calls', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                                  const SizedBox(height: 16),
                                  Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadScheduledCalls,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _calls.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No scheduled calls',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadScheduledCalls,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _calls.length,
                                    itemBuilder: (context, index) {
                                    final call = _calls[index];
                                    final now = DateTime.now();
                                    final isUpcoming = call.scheduledAt.isAfter(now);
                                    
                                    // Calculate end time if duration is set
                                    final endTime = call.maxDurationSeconds > 0
                                        ? call.scheduledAt.add(Duration(seconds: call.maxDurationSeconds))
                                        : null;
                                    final isWithinTimeRange = endTime == null || now.isBefore(endTime);
                                    final canJoin = isUpcoming && 
                                                   call.status == ScheduledCallStatus.scheduled && 
                                                   isWithinTimeRange;
                                    
                                    // Check if user is creator
                                    final isCreator = _currentUserId != null && call.createdBy == _currentUserId;
                                    
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        leading: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            call.callType == CallType.video
                                                ? Icons.videocam
                                                : Icons.phone,
                                            color: Colors.white,
                                          ),
                                        ),
                                        title: Text(
                                          call.title.isNotEmpty ? call.title : 'Scheduled Call',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      _formatDateTime(call.scheduledAt),
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (call.recurrence != null &&
                                                  call.recurrence!.type != RecurrenceType.none) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.repeat, size: 14, color: Colors.grey[600]),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Recurring: ${call.recurrence!.type.name}',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: call.status == ScheduledCallStatus.scheduled
                                                      ? Colors.blue[100]
                                                      : call.status == ScheduledCallStatus.completed
                                                          ? Colors.green[100]
                                                          : Colors.red[100],
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  call.status.name,
                                                  style: TextStyle(
                                                    color: call.status == ScheduledCallStatus.scheduled
                                                        ? Colors.blue[800]
                                                        : call.status == ScheduledCallStatus.completed
                                                            ? Colors.green[800]
                                                            : Colors.red[800],
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        trailing: canJoin || (isCreator && isUpcoming && call.status == ScheduledCallStatus.scheduled)
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (canJoin)
                                                    IconButton(
                                                      icon: const Icon(Icons.video_call),
                                                      color: Colors.green,
                                                      onPressed: _isLoading ? null : () => _joinCall(call),
                                                      tooltip: 'Join call',
                                                    ),
                                                  if (isCreator && isUpcoming && call.status == ScheduledCallStatus.scheduled)
                                                    IconButton(
                                                      icon: const Icon(Icons.cancel_outlined),
                                                      color: Colors.red,
                                                      onPressed: _isLoading ? null : () => _cancelCall(call.id),
                                                      tooltip: 'Cancel',
                                                    ),
                                                ],
                                              )
                                            : null,
                                      ),
                                    );
                                  },
                                  ),
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateScheduledCallScreen(),
            ),
          );
          if (result == true) {
            _loadScheduledCalls();
          }
        },
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

