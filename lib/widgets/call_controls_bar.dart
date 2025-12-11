import 'package:flutter/material.dart';
import '../services/livekit_service.dart';
import 'call_control_button.dart';

class CallControlsBar extends StatelessWidget {
  final LiveKitService liveKitService;
  final CallType callType;
  final VoidCallback onEndCall;

  const CallControlsBar({
    super.key,
    required this.liveKitService,
    required this.callType,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CallControlButton(
            icon: liveKitService.isAudioEnabled
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            onPressed: liveKitService.toggleAudio,
            isActive: liveKitService.isAudioEnabled,
            activeColor: Colors.green,
            inactiveColor: Colors.red,
            tooltip: liveKitService.isAudioEnabled ? 'Mute' : 'Unmute',
          ),
          if (callType == CallType.video) ...[
            CallControlButton(
              icon: liveKitService.isVideoEnabled
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              onPressed: liveKitService.toggleVideo,
              isActive: liveKitService.isVideoEnabled,
              activeColor: Colors.green,
              inactiveColor: Colors.red,
              tooltip: liveKitService.isVideoEnabled
                  ? 'Turn off camera'
                  : 'Turn on camera',
            ),
            CallControlButton(
              icon: Icons.flip_camera_ios_rounded,
              onPressed: () {
                // TODO: Implement camera switch
              },
              isActive: true,
              activeColor: Colors.white,
              tooltip: 'Switch camera',
            ),
          ],
          CallControlButton(
            icon: Icons.call_end_rounded,
            onPressed: onEndCall,
            isActive: false,
            inactiveColor: Colors.red,
            size: 72,
            tooltip: 'End call',
          ),
        ],
      ),
    );
  }
}

