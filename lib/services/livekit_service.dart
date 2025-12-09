import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

class LiveKitService extends ChangeNotifier {
  Room? _room;
  bool _isConnected = false;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  LocalVideoTrack? _localVideoTrack;
  List<RemoteParticipant> _remoteParticipants = [];

  Room? get room => _room;
  bool get isConnected => _isConnected;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isAudioEnabled => _isAudioEnabled;
  LocalVideoTrack? get localVideoTrack => _localVideoTrack;
  List<RemoteParticipant> get remoteParticipants => _remoteParticipants;

  Future<void> connect(
    String url,
    String token,
  ) async {
    try {
      _room = Room();
      
      await _room!.connect(
        url,
        token,
      );

      await _room!.localParticipant?.setCameraEnabled(true);
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      _room!.addListener(_onRoomUpdate);

      _updateLocalTracks();
      _isConnected = true;
      _updateRemoteParticipants();
      notifyListeners();
    } catch (e) {
      debugPrint('Error connecting to room: $e');
      rethrow;
    }
  }

  void _onRoomUpdate() {
    _updateLocalTracks();
    _updateRemoteParticipants();
    notifyListeners();
  }

  void _updateLocalTracks() {
    if (_room?.localParticipant != null) {
      final videoPub = _room!.localParticipant!.videoTrackPublications
          .firstOrNull;
      _localVideoTrack = videoPub?.track;
    }
  }

  void _updateRemoteParticipants() {
    _remoteParticipants = _room?.remoteParticipants.values.toList() ?? [];
  }

  Future<void> toggleVideo() async {
    if (_room?.localParticipant != null) {
      final enabled = _room!.localParticipant!.isCameraEnabled();
      await _room!.localParticipant!.setCameraEnabled(!enabled);
      _isVideoEnabled = !enabled;
      _updateLocalTracks();
      notifyListeners();
    }
  }

  Future<void> toggleAudio() async {
    if (_room?.localParticipant != null) {
      final enabled = _room!.localParticipant!.isMicrophoneEnabled();
      await _room!.localParticipant!.setMicrophoneEnabled(!enabled);
      _isAudioEnabled = !enabled;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _room?.disconnect();
    _room = null;
    _isConnected = false;
    _localVideoTrack = null;
    _remoteParticipants = [];
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
