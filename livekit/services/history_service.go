package services

import (
	"encoding/json"
	"fmt"
	"livekit/database"
	"livekit/models"
	"time"
)

type HistoryService struct {
	db            *database.DB
	historyRepo   *database.CallHistoryRepo
	userRepo      *database.UserRepo
}

func NewHistoryService(db *database.DB) *HistoryService {
	return &HistoryService{
		db:          db,
		historyRepo: database.NewCallHistoryRepo(db),
		userRepo:    database.NewUserRepo(db),
	}
}

func (s *HistoryService) CreateHistoryEntry(callID, roomName, callType string, createdBy int64, participants []string) error {
	_, err := s.historyRepo.Create(callID, roomName, callType, createdBy, participants)
	return err
}

func (s *HistoryService) UpdateHistoryEntry(callID string, endedAt time.Time, duration int, status string) error {
	return s.historyRepo.Update(callID, endedAt, duration, status)
}

func (s *HistoryService) GetCallHistory(userID int64, limit, offset int) ([]*models.CallHistory, error) {
	return s.historyRepo.GetByUserID(userID, limit, offset)
}

func (s *HistoryService) GetCallHistoryByDateRange(userID int64, startDate, endDate time.Time) ([]*models.CallHistory, error) {
	return s.historyRepo.GetByDateRange(userID, startDate, endDate)
}

func (s *HistoryService) GetCallDetails(callID string) (*models.CallHistory, error) {
	return s.historyRepo.GetByCallID(callID)
}

func (s *HistoryService) DeleteCallHistory(callID string) error {
	return s.historyRepo.Delete(callID)
}

func (s *HistoryService) ParseParticipants(participantsJSON string) ([]string, error) {
	var participants []string
	if err := json.Unmarshal([]byte(participantsJSON), &participants); err != nil {
		return nil, fmt.Errorf("failed to parse participants: %w", err)
	}
	return participants, nil
}

