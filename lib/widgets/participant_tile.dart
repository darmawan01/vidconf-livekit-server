import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';
import '../services/livekit_service.dart';
import 'participant_avatar.dart';

class _VideoRendererWrapper extends StatefulWidget {
  final lk.VideoTrack videoTrack;
  final VoidCallback onFirstFrame;

  const _VideoRendererWrapper({
    super.key,
    required this.videoTrack,
    required this.onFirstFrame,
  });

  @override
  State<_VideoRendererWrapper> createState() => _VideoRendererWrapperState();
}

class _VideoRendererWrapperState extends State<_VideoRendererWrapper> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    // Wait for multiple frames to ensure texture is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isReady = true;
            });
            widget.onFirstFrame();
          }
        });
      });
    });
  }

  @override
  void didUpdateWidget(_VideoRendererWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoTrack != widget.videoTrack) {
      // Track changed, reset ready state
      _isReady = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _isReady = true;
              });
            }
          });
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Container(color: Colors.grey[900]);
    }
    return lk.VideoTrackRenderer(
      widget.videoTrack,
      fit: lk.VideoViewFit.cover,
      renderMode: lk.VideoRenderMode.auto,
    );
  }
}

class ParticipantTile extends StatefulWidget {
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

  @override
  State<ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<ParticipantTile> {
  lk.CancelListenFunc? _trackListenerCancel;
  lk.VideoTrack? _currentVideoTrack;
  final GlobalKey _rendererKey = GlobalKey();
  bool _hasRenderedOnce = false;

  @override
  void initState() {
    super.initState();
    _setupTrackListener();
    _updateVideoTrack();
  }

  @override
  void didUpdateWidget(ParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant != widget.participant) {
      _trackListenerCancel?.call();
      _setupTrackListener();
      _updateVideoTrack();
      _hasRenderedOnce = false;
    }
  }

  @override
  void dispose() {
    _trackListenerCancel?.call();
    super.dispose();
  }

  void _setupTrackListener() {
    _trackListenerCancel?.call();
    _trackListenerCancel = widget.participant.events.listen((event) {
      if (event is lk.TrackPublishedEvent ||
          event is lk.TrackUnpublishedEvent ||
          event is lk.TrackSubscribedEvent ||
          event is lk.TrackUnsubscribedEvent) {
        _updateVideoTrack();
      }
    });
  }

  void _updateVideoTrack() {
    final videoPub = widget.participant.videoTrackPublications.firstOrNull;
    final track = videoPub?.track;

    lk.VideoTrack? videoTrack;
    if (track is lk.VideoTrack) {
      if (widget.isLocal) {
        videoTrack = track;
      } else {
        final remotePub = videoPub as lk.RemoteTrackPublication?;
        if (remotePub?.subscribed == true) {
          videoTrack = track;
        }
      }
    }

    if (mounted && _currentVideoTrack != videoTrack) {
      setState(() {
        _currentVideoTrack = videoTrack;
        // Reset render flag when track changes
        if (videoTrack != null) {
          _hasRenderedOnce = false;
        }
      });
    }
  }

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
        final hasVideo = _hasVideo(widget.participant);
        final hasAudio = _hasAudio(widget.participant);
        final name = _getParticipantName(widget.participant);
        final identity = widget.participant.identity;
        final isSpeaking = liveKitService.speakingStates[identity] ?? false;
        final audioLevel = liveKitService.audioLevels[identity];

        if (widget.callType == CallType.voice || !hasVideo) {
          return Container(
            width: widget.width,
            height: widget.height,
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
                    showVideoOffIndicator:
                        widget.callType == CallType.video && !hasVideo,
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
                      child: Icon(Icons.mic_off, color: Colors.red, size: 20),
                    ),
                ],
              ),
            ),
          );
        }

        final hasVideoTrack = _currentVideoTrack != null;

        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasVideoTrack)
                _VideoRendererWrapper(
                  key: _rendererKey,
                  videoTrack: _currentVideoTrack!,
                  onFirstFrame: () {
                    if (mounted) {
                      setState(() {
                        _hasRenderedOnce = true;
                      });
                    }
                  },
                )
              else
                Container(
                  color: Colors.grey[900],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ParticipantAvatar(
                          name: name,
                          size: 80,
                          isSpeaking: isSpeaking,
                          audioLevel: audioLevel,
                          showVideoOffIndicator: true,
                        ),
                        if (widget.callType == CallType.video &&
                            !_hasRenderedOnce) ...[
                          const SizedBox(height: 16),
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                        const Icon(Icons.mic_off, color: Colors.red, size: 14),
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
