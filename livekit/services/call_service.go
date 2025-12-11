package services

import (
	"context"
	"fmt"
	"livekit/database"
	"livekit/models"
	"livekit/websocket"
	"time"

	"github.com/google/uuid"
	"github.com/livekit/protocol/auth"
	livekit "github.com/livekit/protocol/livekit"
	lksdk "github.com/livekit/server-sdk-go/v2"
)

type CallServiceConfig struct {
	APIKey          string
	APISecret       string
	LiveKitHost     string
	EmptyTimeout    int
	MaxParticipants int
}

type CallService struct {
	db                 *database.DB
	config             *CallServiceConfig
	roomClient         *lksdk.RoomServiceClient
	wsHub              *websocket.WebSocketHub
	historyService     *HistoryService
	participantService *ParticipantService
}

type CreateCallResult struct {
	CallID   string `json:"callId"`
	RoomName string `json:"roomName"`
	Token    string `json:"token"`
}

type RespondInvitationResult struct {
	Token    string `json:"token"`
	RoomName string `json:"roomName"`
}

func NewCallService(db *database.DB, cfg *CallServiceConfig, wsHub *websocket.WebSocketHub) (*CallService, error) {
	roomClient := lksdk.NewRoomServiceClient(cfg.LiveKitHost, cfg.APIKey, cfg.APISecret)
	historyService := NewHistoryService(db)
	participantService := NewParticipantService(roomClient, wsHub)

	return &CallService{
		db:                 db,
		config:             cfg,
		roomClient:         roomClient,
		wsHub:              wsHub,
		historyService:     historyService,
		participantService: participantService,
	}, nil
}

func (s *CallService) CreateCallAndInvite(creatorID int64, callType string, inviteeUsernames []string, roomName string) (*CreateCallResult, error) {
	if roomName == "" {
		roomName = uuid.New().String()
	}

	callID := uuid.New().String()

	userRepo := database.NewUserRepo(s.db)
	invitationRepo := database.NewInvitationRepo(s.db)
	callRepo := database.NewCallRepo(s.db)

	creator, err := userRepo.GetByID(creatorID)
	if err != nil {
		return nil, fmt.Errorf("failed to get creator: %w", err)
	}
	if creator == nil {
		return nil, fmt.Errorf("creator not found")
	}

	if err := s.createRoom(roomName, 0, 0); err != nil {
		return nil, fmt.Errorf("failed to create room: %w", err)
	}

	_, err = callRepo.Create(callID, roomName, callType, creatorID)
	if err != nil {
		return nil, fmt.Errorf("failed to create call record: %w", err)
	}

	var createdInvitations []*models.Invitation
	for _, username := range inviteeUsernames {
		invitee, err := userRepo.GetByUsername(username)
		if err != nil {
			continue
		}
		if invitee == nil {
			continue
		}

		invitation, err := invitationRepo.Create(callID, creatorID, invitee.ID, callType, roomName)
		if err != nil {
			continue
		}
		createdInvitations = append(createdInvitations, invitation)
	}

	if s.wsHub != nil {
		for _, invitation := range createdInvitations {
			if invitation.Status == "pending" {
				s.wsHub.BroadcastInvitation(invitation.Invitee, invitation)
			}
		}
	}

	// Create initial call history entry with pending status
	participantNames := []string{creator.Username}
	for _, username := range inviteeUsernames {
		participantNames = append(participantNames, username)
	}
	if err := s.historyService.CreateHistoryEntry(callID, roomName, callType, creatorID, participantNames); err != nil {
		// Log error but don't fail call creation
		fmt.Printf("Failed to create call history entry: %v\n", err)
	}
	// Set initial status to pending (will be updated when call is accepted/rejected/ended)
	if err := s.historyService.UpdateHistoryEntry(callID, time.Now(), 0, "pending"); err != nil {
		fmt.Printf("Failed to update call history status: %v\n", err)
	}

	token, err := s.generateToken(roomName, creator.Username)
	if err != nil {
		return nil, fmt.Errorf("failed to generate token: %w", err)
	}

	return &CreateCallResult{
		CallID:   callID,
		RoomName: roomName,
		Token:    token,
	}, nil
}

func (s *CallService) RespondToInvitation(invitationID, userID int64, action string) (*RespondInvitationResult, error) {
	invitationRepo := database.NewInvitationRepo(s.db)
	invitation, err := invitationRepo.GetByID(invitationID)
	if err != nil {
		return nil, fmt.Errorf("failed to get invitation: %w", err)
	}
	if invitation == nil {
		return nil, fmt.Errorf("invitation not found")
	}

	if invitation.InviteeID != userID {
		return nil, fmt.Errorf("unauthorized")
	}

	if invitation.Status != "pending" {
		return nil, fmt.Errorf("invitation already responded")
	}

	status := "rejected"
	if action == "accept" {
		status = "accepted"
	}

	if err := invitationRepo.UpdateStatus(invitationID, status); err != nil {
		return nil, fmt.Errorf("failed to update invitation status: %w", err)
	}

	if action == "reject" {
		// Update call history with rejected status
		if err := s.historyService.UpdateHistoryEntry(invitation.CallID, time.Now(), 0, "rejected"); err != nil {
			fmt.Printf("Failed to update call history for rejection: %v\n", err)
		}

		if s.wsHub != nil {
			userRepo := database.NewUserRepo(s.db)
			inviter, err := userRepo.GetByID(invitation.InviterID)
			if err == nil && inviter != nil {
				s.wsHub.BroadcastInvitationResponse(inviter.Username, invitationID, invitation.Invitee, "rejected")
			}
		}
		return nil, nil
	}

	userRepo := database.NewUserRepo(s.db)
	user, err := userRepo.GetByID(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	token, err := s.generateToken(invitation.RoomName, user.Username)
	if err != nil {
		return nil, fmt.Errorf("failed to generate token: %w", err)
	}

	if s.wsHub != nil {
		userRepo := database.NewUserRepo(s.db)
		inviter, err := userRepo.GetByID(invitation.InviterID)
		if err == nil && inviter != nil {
			s.wsHub.BroadcastInvitationResponse(inviter.Username, invitationID, invitation.Invitee, "accepted")
		}
	}

	return &RespondInvitationResult{
		Token:    token,
		RoomName: invitation.RoomName,
	}, nil
}

func (s *CallService) CreateRoomForScheduledCall(roomName string, maxParticipants, maxDurationSeconds int) error {
	return s.createRoom(roomName, maxParticipants, maxDurationSeconds)
}

func (s *CallService) createRoom(roomName string, maxParticipants, maxDurationSeconds int) error {
	at := auth.NewAccessToken(s.config.APIKey, s.config.APISecret)
	grant := &auth.VideoGrant{
		RoomCreate: true,
	}
	at.SetVideoGrant(grant).
		SetIdentity("room-creator").
		SetValidFor(5 * time.Minute)

	ctx := context.Background()
	emptyTimeout := uint32(s.config.EmptyTimeout)
	if emptyTimeout == 0 {
		emptyTimeout = 0
	}

	maxParticipantsUint := uint32(maxParticipants)
	if maxParticipants <= 0 {
		maxParticipantsUint = 0
	}

	_, err := s.roomClient.CreateRoom(ctx, &livekit.CreateRoomRequest{
		Name:            roomName,
		EmptyTimeout:    emptyTimeout,
		MaxParticipants: maxParticipantsUint,
	})

	if err != nil {
		return fmt.Errorf("failed to create room: %w", err)
	}

	return nil
}

func (s *CallService) generateToken(roomName, identity string) (string, error) {
	at := auth.NewAccessToken(s.config.APIKey, s.config.APISecret)
	grant := &auth.VideoGrant{
		RoomJoin:   true,
		RoomCreate: true,
		Room:       roomName,
	}
	at.SetVideoGrant(grant).
		SetIdentity(identity).
		SetValidFor(24 * time.Hour)

	token, err := at.ToJWT()
	if err != nil {
		return "", fmt.Errorf("failed to generate token: %w", err)
	}

	return token, nil
}

func (s *CallService) EndCall(callID string, userID int64) error {
	callRepo := database.NewCallRepo(s.db)
	call, err := callRepo.GetByCallID(callID)
	if err != nil {
		return fmt.Errorf("failed to get call: %w", err)
	}
	if call == nil {
		return fmt.Errorf("call not found")
	}

	participants, err := s.participantService.ListParticipants(call.RoomName)
	if err != nil {
		participants = []*livekit.ParticipantInfo{}
	}

	participantNames := make([]string, 0, len(participants))

	for _, p := range participants {
		if p.Identity != "" {
			participantNames = append(participantNames, p.Identity)
		}
	}

	startedAt := call.CreatedAt
	endedAt := time.Now()
	duration := int(endedAt.Sub(startedAt).Seconds())

	// Check if history entry already exists (created when call was initiated)
	existingHistory, err := s.historyService.GetCallDetails(callID)
	if err != nil || existingHistory == nil {
		// Create history entry if it doesn't exist (shouldn't happen, but handle gracefully)
		if err := s.historyService.CreateHistoryEntry(callID, call.RoomName, call.CallType, call.CreatedBy, participantNames); err != nil {
			return fmt.Errorf("failed to create history entry: %w", err)
		}
	}

	// Update history entry with completed status
	if err := s.historyService.UpdateHistoryEntry(callID, endedAt, duration, "completed"); err != nil {
		return fmt.Errorf("failed to update history entry: %w", err)
	}

	if err := callRepo.UpdateStatus(callID, "ended"); err != nil {
		return fmt.Errorf("failed to update call status: %w", err)
	}

	// Broadcast call_ended event to all participants
	if s.wsHub != nil {
		for _, participantName := range participantNames {
			s.wsHub.BroadcastCallEnded(participantName, callID)
		}
	}

	return nil
}

func (s *CallService) CancelCall(callID string, userID int64) error {
	callRepo := database.NewCallRepo(s.db)
	call, err := callRepo.GetByCallID(callID)
	if err != nil {
		return fmt.Errorf("failed to get call: %w", err)
	}
	if call == nil {
		return fmt.Errorf("call not found")
	}

	// Only creator can cancel the call
	if call.CreatedBy != userID {
		return fmt.Errorf("unauthorized: only creator can cancel the call")
	}

	// Get all pending invitations for this call
	invitationRepo := database.NewInvitationRepo(s.db)
	invitations, err := invitationRepo.GetCallParticipants(callID)
	if err != nil {
		return fmt.Errorf("failed to get invitations: %w", err)
	}

	// Update all pending invitations to cancelled
	userRepo := database.NewUserRepo(s.db)
	var inviteeUsernames []string
	for _, invitation := range invitations {
		if invitation.Status == "pending" {
			if err := invitationRepo.UpdateStatus(invitation.ID, "cancelled"); err != nil {
				fmt.Printf("Failed to update invitation %d status: %v\n", invitation.ID, err)
				continue
			}
			// Get invitee username for notification
			invitee, err := userRepo.GetByID(invitation.InviteeID)
			if err == nil && invitee != nil {
				inviteeUsernames = append(inviteeUsernames, invitee.Username)
			}
		}
	}

	// Update call status to cancelled
	if err := callRepo.UpdateStatus(callID, "cancelled"); err != nil {
		return fmt.Errorf("failed to update call status: %w", err)
	}

	// Update call history status to cancelled
	if err := s.historyService.UpdateHistoryEntry(callID, time.Time{}, 0, "cancelled"); err != nil {
		fmt.Printf("Failed to update call history status: %v\n", err)
	}

	// Broadcast call_cancelled event to all invitees
	if s.wsHub != nil {
		for _, inviteeUsername := range inviteeUsernames {
			s.wsHub.BroadcastCallCancelled(inviteeUsername, callID)
		}
	}

	return nil
}
