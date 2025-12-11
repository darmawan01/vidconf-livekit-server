package services

import (
	"fmt"
	"livekit/database"
	"livekit/models"
	"livekit/websocket"
	"time"

	"github.com/google/uuid"
)

type ScheduledService struct {
	db                        *database.DB
	scheduledCallRepo         *database.ScheduledCallRepo
	scheduledCallInvitationRepo *database.ScheduledCallInvitationRepo
	userRepo                  *database.UserRepo
	callService               *CallService
	wsHub                     *websocket.WebSocketHub
}

func NewScheduledService(db *database.DB, callService *CallService, wsHub *websocket.WebSocketHub) *ScheduledService {
	return &ScheduledService{
		db:                        db,
		scheduledCallRepo:         database.NewScheduledCallRepo(db),
		scheduledCallInvitationRepo: database.NewScheduledCallInvitationRepo(db),
		userRepo:                  database.NewUserRepo(db),
		callService:               callService,
		wsHub:                     wsHub,
	}
}

type CreateScheduledCallRequest struct {
	CallType          string    `json:"callType"`
	ScheduledAt       time.Time `json:"scheduledAt"`
	Timezone          string    `json:"timezone"`
	Invitees          []string  `json:"invitees"`
	Recurrence        string    `json:"recurrence"` // JSON
	Title             string    `json:"title"`
	Description       string    `json:"description"`
	MaxParticipants   int       `json:"maxParticipants"`
	MaxDurationSeconds int      `json:"maxDurationSeconds"`
}

func (s *ScheduledService) CreateScheduledCall(creatorID int64, req CreateScheduledCallRequest) (*models.ScheduledCall, error) {
	callID := uuid.New().String()
	roomName := uuid.New().String()
	joinLink := fmt.Sprintf("app://call/join?callId=%s", callID)

	if req.Timezone == "" {
		req.Timezone = "UTC"
	}

	recurrenceJSON := req.Recurrence
	if recurrenceJSON == "" {
		recurrenceJSON = `{"type":"none"}`
	}

	maxParticipants := req.MaxParticipants
	if maxParticipants <= 0 {
		maxParticipants = 20
	}

	maxDurationSeconds := req.MaxDurationSeconds
	if maxDurationSeconds < 0 {
		maxDurationSeconds = 0
	}

	call, err := s.scheduledCallRepo.Create(callID, roomName, req.CallType, creatorID, req.ScheduledAt, req.Timezone, recurrenceJSON, req.Title, req.Description, joinLink, maxParticipants, maxDurationSeconds)
	if err != nil {
		return nil, fmt.Errorf("failed to create scheduled call: %w", err)
	}

	// Track invitees for broadcasting
	var inviteeUsernames []string

	for _, username := range req.Invitees {
		invitee, err := s.userRepo.GetByUsername(username)
		if err != nil || invitee == nil {
			continue
		}

		_, err = s.scheduledCallInvitationRepo.Create(call.ID, invitee.ID)
		if err != nil {
			continue
		}

		inviteeUsernames = append(inviteeUsernames, username)
	}

	// Broadcast to creator and all invitees
	if s.wsHub != nil {
		creator, err := s.userRepo.GetByID(creatorID)
		if err == nil && creator != nil {
			// Broadcast to creator
			s.wsHub.BroadcastScheduledCallCreated(creator.Username, call)
			// Broadcast to all invitees
			for _, inviteeUsername := range inviteeUsernames {
				s.wsHub.BroadcastScheduledCallCreated(inviteeUsername, call)
			}
		}
	}

	return call, nil
}

func (s *ScheduledService) GetScheduledCalls(userID int64, status string) ([]*models.ScheduledCall, error) {
	// Get calls created by user
	createdCalls, err := s.scheduledCallRepo.GetByUserID(userID, status)
	if err != nil {
		return nil, err
	}

	// Get calls where user is an invitee
	invitedCalls, err := s.scheduledCallRepo.GetByInviteeID(userID, status)
	if err != nil {
		return nil, err
	}

	// Combine and deduplicate calls (in case user is both creator and invitee)
	callMap := make(map[int64]*models.ScheduledCall)
	for _, call := range createdCalls {
		callMap[call.ID] = call
	}
	for _, call := range invitedCalls {
		if _, exists := callMap[call.ID]; !exists {
			callMap[call.ID] = call
		}
	}

	// Convert map to slice
	calls := make([]*models.ScheduledCall, 0, len(callMap))
	for _, call := range callMap {
		calls = append(calls, call)
	}

	// Sort by scheduled_at
	for i := 0; i < len(calls)-1; i++ {
		for j := i + 1; j < len(calls); j++ {
			if calls[i].ScheduledAt.After(calls[j].ScheduledAt) {
				calls[i], calls[j] = calls[j], calls[i]
			}
		}
	}

	// Populate invitees for each call
	for _, call := range calls {
		if err := s.populateInvitees(call); err != nil {
			// Log error but don't fail the entire request
			fmt.Printf("Failed to populate invitees for call %d: %v\n", call.ID, err)
		}
	}

	return calls, nil
}

func (s *ScheduledService) GetScheduledCall(id int64) (*models.ScheduledCall, error) {
	call, err := s.scheduledCallRepo.GetByID(id)
	if err != nil {
		return nil, err
	}
	if call == nil {
		return nil, nil
	}

	// Populate invitees
	if err := s.populateInvitees(call); err != nil {
		// Log error but don't fail the request
		fmt.Printf("Failed to populate invitees for call %d: %v\n", call.ID, err)
	}

	return call, nil
}

func (s *ScheduledService) UpdateScheduledCall(id int64, updates map[string]interface{}) error {
	call, err := s.scheduledCallRepo.GetByID(id)
	if err != nil {
		return err
	}
	if call == nil {
		return fmt.Errorf("scheduled call not found")
	}

	if title, ok := updates["title"].(string); ok {
		_, err = s.db.Conn().Exec(`UPDATE scheduled_calls SET title = ?, updated_at = ? WHERE id = ?`, title, time.Now(), id)
		if err != nil {
			return err
		}
	}

	if description, ok := updates["description"].(string); ok {
		_, err = s.db.Conn().Exec(`UPDATE scheduled_calls SET description = ?, updated_at = ? WHERE id = ?`, description, time.Now(), id)
		if err != nil {
			return err
		}
	}

	if scheduledAt, ok := updates["scheduledAt"].(time.Time); ok {
		_, err = s.db.Conn().Exec(`UPDATE scheduled_calls SET scheduled_at = ?, updated_at = ? WHERE id = ?`, scheduledAt, time.Now(), id)
		if err != nil {
			return err
		}
	}

	return nil
}

func (s *ScheduledService) CancelScheduledCall(id int64, userID int64) error {
	call, err := s.scheduledCallRepo.GetByID(id)
	if err != nil {
		return err
	}
	if call == nil {
		return fmt.Errorf("scheduled call not found")
	}
	if call.CreatedBy != userID {
		return fmt.Errorf("unauthorized")
	}

	return s.scheduledCallRepo.UpdateStatus(id, "cancelled")
}

func (s *ScheduledService) StartScheduledCall(id int64, userID int64) (*CreateCallResult, error) {
	call, err := s.scheduledCallRepo.GetByID(id)
	if err != nil {
		return nil, err
	}
	if call == nil {
		return nil, fmt.Errorf("scheduled call not found")
	}

	// Check authorization: user must be creator or invitee
	if call.CreatedBy != userID {
		isInvitee, err := s.IsInvitee(id, userID)
		if err != nil {
			return nil, fmt.Errorf("failed to check invitee status: %w", err)
		}
		if !isInvitee {
			return nil, fmt.Errorf("unauthorized: user is not creator or invitee")
		}
	}

	if call.Status != "scheduled" {
		return nil, fmt.Errorf("call is not in scheduled status")
	}

	// Time range validation
	now := time.Now()
	if now.Before(call.ScheduledAt) {
		// Allow early join (optional - can be changed to return error if needed)
		// For now, we allow early join
	}

	// Check if meeting has ended (scheduledAt + duration)
	if call.MaxDurationSeconds > 0 {
		endTime := call.ScheduledAt.Add(time.Duration(call.MaxDurationSeconds) * time.Second)
		if now.After(endTime) {
			return nil, fmt.Errorf("meeting has ended")
		}
	}

	if err := s.callService.CreateRoomForScheduledCall(call.RoomName, call.MaxParticipants, call.MaxDurationSeconds); err != nil {
		return nil, fmt.Errorf("failed to create room: %w", err)
	}

	result, err := s.callService.CreateCallAndInvite(call.CreatedBy, call.CallType, []string{}, call.RoomName)
	if err != nil {
		return nil, err
	}

	s.scheduledCallRepo.UpdateStatus(id, "started")

	return result, nil
}

func (s *ScheduledService) GetUpcomingScheduledCalls(limit int) ([]*models.ScheduledCall, error) {
	return s.scheduledCallRepo.GetUpcoming(limit)
}

func (s *ScheduledService) UpdateReminderSent(id int64) error {
	return s.scheduledCallRepo.UpdateReminderSent(id)
}

// populateInvitees populates the Invitees field from scheduled_call_invitations table
func (s *ScheduledService) populateInvitees(call *models.ScheduledCall) error {
	invitations, err := s.scheduledCallInvitationRepo.GetByScheduledCallID(call.ID)
	if err != nil {
		return fmt.Errorf("failed to get invitations: %w", err)
	}

	invitees := make([]string, 0, len(invitations))
	for _, inv := range invitations {
		user, err := s.userRepo.GetByID(inv.InviteeID)
		if err != nil || user == nil {
			continue
		}
		invitees = append(invitees, user.Username)
	}

	call.Invitees = invitees
	return nil
}

// IsInvitee checks if a user is an invitee for a scheduled call
func (s *ScheduledService) IsInvitee(scheduledCallID int64, userID int64) (bool, error) {
	invitations, err := s.scheduledCallInvitationRepo.GetByScheduledCallID(scheduledCallID)
	if err != nil {
		return false, fmt.Errorf("failed to get invitations: %w", err)
	}

	for _, inv := range invitations {
		if inv.InviteeID == userID {
			return true, nil
		}
	}

	return false, nil
}
