import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../services/livekit_service.dart';
import 'participant_tile.dart';

class ParticipantGrid extends StatelessWidget {
  final List<lk.Participant> participants;
  final CallType callType;

  const ParticipantGrid({
    super.key,
    required this.participants,
    required this.callType,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final participantCount = participants.length;

    if (callType == CallType.voice) {
      return _buildVoiceCallView(participants);
    }

    if (participantCount == 1) {
      return _buildSingleParticipantView(participants[0]);
    } else if (participantCount == 2) {
      return _buildTwoParticipantView(participants);
    } else if (participantCount <= 4) {
      return _buildGridLayout(participants, 2);
    } else {
      return _buildGridLayout(participants, 3);
    }
  }

  Widget _buildVoiceCallView(List<lk.Participant> participants) {
    return Container(
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final participant = participants[index];
          final isLocal = participant is lk.LocalParticipant;
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: ParticipantTile(
              participant: participant,
              isLocal: isLocal,
              callType: CallType.voice,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSingleParticipantView(lk.Participant participant) {
    final isLocal = participant is lk.LocalParticipant;
    return ParticipantTile(
      participant: participant,
      isLocal: isLocal,
      callType: CallType.video,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildTwoParticipantView(List<lk.Participant> participants) {
    return Row(
      children: participants.map((participant) {
        final isLocal = participant is lk.LocalParticipant;
        return Expanded(
          child: ParticipantTile(
            participant: participant,
            isLocal: isLocal,
            callType: CallType.video,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGridLayout(List<lk.Participant> participants, int crossAxisCount) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.0,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final isLocal = participant is lk.LocalParticipant;
        return ParticipantTile(
          participant: participant,
          isLocal: isLocal,
          callType: CallType.video,
        );
      },
    );
  }
}

