import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'audio_level_service.dart';

enum CallType {
  video,
  voice,
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class LiveKitService extends ChangeNotifier {
  Room? _room;
  bool _isConnected = false;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  LocalVideoTrack? _localVideoTrack;
  List<RemoteParticipant> _remoteParticipants = [];
  CallType? _callType;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  DateTime? _callStartTime;
  Timer? _callDurationTimer;
  Duration _callDuration = Duration.zero;
  AudioLevelService? _audioLevelService;
  StreamSubscription? _roomEventsSubscription;

  Room? get room => _room;
  bool get isConnected => _isConnected;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isAudioEnabled => _isAudioEnabled;
  LocalVideoTrack? get localVideoTrack => _localVideoTrack;
  List<RemoteParticipant> get remoteParticipants => _remoteParticipants;
  CallType? get callType => _callType;
  ConnectionStatus get connectionStatus => _connectionStatus;
  Duration get callDuration => _callDuration;
  AudioLevelService? get audioLevelService => _audioLevelService;
  Map<String, double> get audioLevels => _audioLevelService?.audioLevels ?? {};
  Map<String, bool> get speakingStates => _audioLevelService?.speakingStates ?? {};

  Future<void> connect(
    String url,
    String token,
    CallType callType,
  ) async {
    try {
      _callType = callType;
      _connectionStatus = ConnectionStatus.connecting;
      notifyListeners();

      _room = Room();
      
      await _room!.connect(
        url,
        token,
      );

      await _room!.localParticipant?.setMicrophoneEnabled(true);
      
      if (callType == CallType.video) {
        await _room!.localParticipant?.setCameraEnabled(true);
        _isVideoEnabled = true;
      } else {
        await _room!.localParticipant?.setCameraEnabled(false);
        _isVideoEnabled = false;
      }

      _room!.addListener(_onRoomUpdate);
      _setupAudioLevelTracking();
      _setupRoomEvents();

      _updateLocalTracks();
      _isConnected = true;
      _connectionStatus = ConnectionStatus.connected;
      _callStartTime = DateTime.now();
      _startCallDurationTimer();
      _updateRemoteParticipants();
      notifyListeners();
    } catch (e) {
      debugPrint('Error connecting to room: $e');
      _connectionStatus = ConnectionStatus.failed;
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  void _startCallDurationTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callStartTime != null) {
        _callDuration = DateTime.now().difference(_callStartTime!);
        notifyListeners();
      }
    });
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
    _updateAudioLevelTracking();
  }

  void _setupAudioLevelTracking() {
    _audioLevelService = AudioLevelService();
    _audioLevelService?.addListener(() {
      notifyListeners();
    });
  }

  void _setupRoomEvents() {
    _roomEventsSubscription?.cancel();
    _room?.events.listen((event) {
      _updateRemoteParticipants();
      _updateAudioLevelTracking();
    });
  }

  void _updateAudioLevelTracking() {
    if (_audioLevelService == null || _room == null) return;

    final trackedIdentities = _audioLevelService!.audioLevels.keys.toSet();
    final currentIdentities = <String>{};

    for (final participant in _room!.remoteParticipants.values) {
      currentIdentities.add(participant.identity);
      final audioPub = participant.audioTrackPublications.firstOrNull;
      if (audioPub?.track != null) {
        final audioTrack = audioPub!.track;
        if (audioTrack is RemoteAudioTrack) {
          _audioLevelService!.startTrackingParticipant(
            participant.identity,
            audioTrack,
          );
        }
      }
    }

    for (final identity in trackedIdentities) {
      if (!currentIdentities.contains(identity)) {
        _audioLevelService!.stopTrackingParticipant(identity);
      }
    }
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
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
    _callStartTime = null;
    _callDuration = Duration.zero;
    _roomEventsSubscription?.cancel();
    _roomEventsSubscription = null;
    _audioLevelService?.stopAll();
    _audioLevelService = null;
    await _room?.disconnect();
    _room = null;
    _isConnected = false;
    _connectionStatus = ConnectionStatus.disconnected;
    _localVideoTrack = null;
    _remoteParticipants = [];
    _callType = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
