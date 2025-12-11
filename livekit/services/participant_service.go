package services

import (
	"context"
	"fmt"
	"livekit/websocket"

	livekit "github.com/livekit/protocol/livekit"
	lksdk "github.com/livekit/server-sdk-go/v2"
)

type ParticipantService struct {
	roomClient *lksdk.RoomServiceClient
	wsHub      *websocket.WebSocketHub
}

func NewParticipantService(roomClient *lksdk.RoomServiceClient, wsHub *websocket.WebSocketHub) *ParticipantService {
	return &ParticipantService{
		roomClient: roomClient,
		wsHub:      wsHub,
	}
}

func (s *ParticipantService) ListParticipants(roomName string) ([]*livekit.ParticipantInfo, error) {
	ctx := context.Background()
	res, err := s.roomClient.ListParticipants(ctx, &livekit.ListParticipantsRequest{
		Room: roomName,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to list participants: %w", err)
	}
	return res.Participants, nil
}

func (s *ParticipantService) GetParticipant(roomName, identity string) (*livekit.ParticipantInfo, error) {
	ctx := context.Background()
	res, err := s.roomClient.GetParticipant(ctx, &livekit.RoomParticipantIdentity{
		Room:     roomName,
		Identity: identity,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get participant: %w", err)
	}
	return res, nil
}

func (s *ParticipantService) UpdateParticipant(roomName, identity string, permission *livekit.ParticipantPermission, metadata string) error {
	ctx := context.Background()
	req := &livekit.UpdateParticipantRequest{
		Room:     roomName,
		Identity: identity,
	}
	if permission != nil {
		req.Permission = permission
	}
	if metadata != "" {
		req.Metadata = metadata
	}

	_, err := s.roomClient.UpdateParticipant(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to update participant: %w", err)
	}
	return nil
}

func (s *ParticipantService) RemoveParticipant(roomName, identity string) error {
	ctx := context.Background()
	_, err := s.roomClient.RemoveParticipant(ctx, &livekit.RoomParticipantIdentity{
		Room:     roomName,
		Identity: identity,
	})
	if err != nil {
		return fmt.Errorf("failed to remove participant: %w", err)
	}
	return nil
}

func (s *ParticipantService) MutePublishedTrack(roomName, identity, trackSid string, muted bool) error {
	ctx := context.Background()
	_, err := s.roomClient.MutePublishedTrack(ctx, &livekit.MuteRoomTrackRequest{
		Room:     roomName,
		Identity: identity,
		TrackSid: trackSid,
		Muted:    muted,
	})
	if err != nil {
		return fmt.Errorf("failed to mute track: %w", err)
	}
	return nil
}
