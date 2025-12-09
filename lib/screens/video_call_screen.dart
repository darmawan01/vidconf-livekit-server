import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';
import '../services/livekit_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomName;
  final String userName;

  const VideoCallScreen({
    super.key,
    required this.roomName,
    required this.userName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<LiveKitService>(
      builder: (context, liveKitService, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text('Room: ${widget.roomName}'),
            backgroundColor: Colors.black87,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                await liveKitService.disconnect();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          body: Stack(
            children: [
              _buildVideoView(liveKitService),
              _buildControls(liveKitService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoView(LiveKitService liveKitService) {
    return Column(
      children: [
        Expanded(
          child: liveKitService.localVideoTrack != null
              ? lk.VideoTrackRenderer(
                  liveKitService.localVideoTrack!,
                  fit: lk.VideoViewFit.cover,
                )
              : const Center(
                  child: CircularProgressIndicator(),
                ),
        ),
        if (liveKitService.remoteParticipants.isNotEmpty)
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemCount: liveKitService.remoteParticipants.length,
              itemBuilder: (context, index) {
                final participant = liveKitService.remoteParticipants[index];
                final videoPub = participant.videoTrackPublications
                    .firstOrNull;
                final videoTrack = videoPub?.track;
                
                if (videoTrack != null) {
                  return lk.VideoTrackRenderer(
                    videoTrack,
                    fit: lk.VideoViewFit.cover,
                  );
                }
                return Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: Text(
                      participant.identity,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildControls(LiveKitService liveKitService) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black87,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: liveKitService.isAudioEnabled
                  ? Icons.mic
                  : Icons.mic_off,
              onPressed: liveKitService.toggleAudio,
              color: liveKitService.isAudioEnabled
                  ? Colors.white
                  : Colors.red,
            ),
            _buildControlButton(
              icon: liveKitService.isVideoEnabled
                  ? Icons.videocam
                  : Icons.videocam_off,
              onPressed: liveKitService.toggleVideo,
              color: liveKitService.isVideoEnabled
                  ? Colors.white
                  : Colors.red,
            ),
            _buildControlButton(
              icon: Icons.call_end,
              onPressed: () async {
                await liveKitService.disconnect();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        iconSize: 28,
      ),
    );
  }
}
