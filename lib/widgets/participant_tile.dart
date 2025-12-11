import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';
import '../services/livekit_service.dart';
import 'participant_avatar.dart';

class ParticipantTile extends StatelessWidget {
  final lk.Participant participant;
  final bool isLocal;
  final CallType callType;
  final double? width;
  final double? height;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isLocal = false,
    required this.callType,
    this.width,
    this.height,
  });

  bool _hasVideo(lk.Participant participant) {
    final videoPub = participant.videoTrackPublications.firstOrNull;
    return videoPub?.track != null && videoPub?.muted == false;
  }

  bool _hasAudio(lk.Participant participant) {
    final audioPub = participant.audioTrackPublications.firstOrNull;
    return audioPub?.track != null && audioPub?.muted == false;
  }

  String _getParticipantName(lk.Participant participant) {
    final name = participant.name;
    return (name.isNotEmpty) ? name : participant.identity;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LiveKitService>(
      builder: (context, liveKitService, child) {
        final hasVideo = _hasVideo(participant);
        final hasAudio = _hasAudio(participant);
        final name = _getParticipantName(participant);
        final videoPub = participant.videoTrackPublications.firstOrNull;
        final videoTrack = videoPub?.track;
        final identity = participant.identity;
        final isSpeaking = liveKitService.speakingStates[identity] ?? false;
        final audioLevel = liveKitService.audioLevels[identity];

        if (callType == CallType.voice || !hasVideo) {
          return Container(
            width: width,
            height: height,
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ParticipantAvatar(
                    name: name,
                    size: 120,
                    isSpeaking: isSpeaking,
                    audioLevel: audioLevel,
                    showVideoOffIndicator: callType == CallType.video && !hasVideo,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!hasAudio)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(
                        Icons.mic_off,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        final videoTrackTyped = videoTrack is lk.VideoTrack ? videoTrack : null;

        return Container(
          width: width,
          height: height,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (videoTrackTyped != null)
                lk.VideoTrackRenderer(
                  videoTrackTyped,
                  fit: lk.VideoViewFit.cover,
                )
              else
                Container(
                  color: Colors.grey[900],
                  child: Center(
                    child: ParticipantAvatar(
                      name: name,
                      size: 80,
                      isSpeaking: isSpeaking,
                      audioLevel: audioLevel,
                      showVideoOffIndicator: true,
                    ),
                  ),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!hasAudio) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.mic_off,
                          color: Colors.red,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

