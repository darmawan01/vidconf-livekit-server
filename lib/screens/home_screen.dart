import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/livekit_service.dart';
import '../utils/token_generator.dart';
import 'video_call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roomNameController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _roomNameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    if (_roomNameController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter room name and your name')),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final liveKitService = context.read<LiveKitService>();
      
      const livekitUrl = 'ws://localhost:7880';
      const apiKey = 'devkey';
      const apiSecret = 'secret';
      
      final token = generateLiveKitToken(
        apiKey: apiKey,
        apiSecret: apiSecret,
        roomName: _roomNameController.text,
        participantName: _nameController.text,
      );

      await liveKitService.connect(livekitUrl, token);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              roomName: _roomNameController.text,
              userName: _nameController.text,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining room: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Conference'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_call,
              size: 80,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _roomNameController,
              decoration: const InputDecoration(
                labelText: 'Room Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isJoining ? null : _joinRoom,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isJoining
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

