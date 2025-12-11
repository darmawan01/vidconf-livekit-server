import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

class AudioLevelService extends ChangeNotifier {
  final Map<String, double> _audioLevels = {};
  final Map<String, bool> _speakingStates = {};
  final Map<String, Timer> _pollTimers = {};
  
  static const double _speakingThreshold = 0.1;
  static const Duration _pollInterval = Duration(milliseconds: 100);
  static const Duration _debounceDuration = Duration(milliseconds: 200);
  
  final Map<String, Timer> _debounceTimers = {};

  Map<String, double> get audioLevels => Map.unmodifiable(_audioLevels);
  Map<String, bool> get speakingStates => Map.unmodifiable(_speakingStates);

  double? getAudioLevel(String participantIdentity) {
    return _audioLevels[participantIdentity];
  }

  bool isSpeaking(String participantIdentity) {
    return _speakingStates[participantIdentity] ?? false;
  }

  void startTrackingParticipant(String participantIdentity, RemoteAudioTrack? audioTrack) {
    if (audioTrack == null) {
      stopTrackingParticipant(participantIdentity);
      return;
    }

    if (_pollTimers.containsKey(participantIdentity)) {
      return;
    }

    _audioLevels[participantIdentity] = 0.0;
    _speakingStates[participantIdentity] = false;

    _pollTimers[participantIdentity] = Timer.periodic(_pollInterval, (timer) {
      _updateAudioLevel(participantIdentity, audioTrack);
    });

    notifyListeners();
  }

  void _updateAudioLevel(String participantIdentity, RemoteAudioTrack audioTrack) {
    try {
      final isMuted = audioTrack.muted;
      if (isMuted) {
        _audioLevels[participantIdentity] = 0.0;
        _updateSpeakingState(participantIdentity, false);
        return;
      }
      
      final simulatedLevel = 0.5 + (math.Random().nextDouble() * 0.3);
      final normalizedLevel = math.max(0.0, math.min(1.0, simulatedLevel));
      
      _audioLevels[participantIdentity] = normalizedLevel;
      _updateSpeakingState(participantIdentity, normalizedLevel > _speakingThreshold);
    } catch (e) {
      debugPrint('Error getting audio level: $e');
      _audioLevels[participantIdentity] = 0.0;
      _updateSpeakingState(participantIdentity, false);
    }
  }

  void _updateSpeakingState(String participantIdentity, bool isSpeaking) {
    final currentState = _speakingStates[participantIdentity] ?? false;
    if (currentState == isSpeaking) {
      return;
    }

    _debounceTimers[participantIdentity]?.cancel();
    
    if (isSpeaking) {
      _speakingStates[participantIdentity] = true;
      notifyListeners();
    } else {
      final timer = Timer(_debounceDuration, () {
        if (_speakingStates[participantIdentity] == true) {
          _speakingStates[participantIdentity] = false;
          notifyListeners();
        }
      });
      _debounceTimers[participantIdentity] = timer;
    }
  }

  void stopTrackingParticipant(String participantIdentity) {
    _pollTimers[participantIdentity]?.cancel();
    _pollTimers.remove(participantIdentity);
    _audioLevels.remove(participantIdentity);
    _speakingStates.remove(participantIdentity);
    _debounceTimers[participantIdentity]?.cancel();
    _debounceTimers.remove(participantIdentity);
    notifyListeners();
  }

  void stopAll() {
    for (final timer in _pollTimers.values) {
      timer.cancel();
    }
    _pollTimers.clear();
    _audioLevels.clear();
    _speakingStates.clear();
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopAll();
    super.dispose();
  }
}

