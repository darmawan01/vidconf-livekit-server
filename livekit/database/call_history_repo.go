package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"livekit/models"
	"time"
)

type CallHistoryRepo struct {
	db *DB
}

func NewCallHistoryRepo(db *DB) *CallHistoryRepo {
	return &CallHistoryRepo{db: db}
}

func (r *CallHistoryRepo) Create(callID, roomName, callType string, createdBy int64, participants []string) (*models.CallHistory, error) {
	participantsJSON, err := json.Marshal(participants)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal participants: %w", err)
	}

	result, err := r.db.conn.Exec(
		`INSERT INTO call_history (call_id, room_name, call_type, created_by, participants, started_at, status)
		 VALUES (?, ?, ?, ?, ?, ?, 'pending')`,
		callID, roomName, callType, createdBy, string(participantsJSON), time.Now(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create call history: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("failed to get last insert id: %w", err)
	}

	return &models.CallHistory{
		ID:           id,
		CallID:       callID,
		RoomName:     roomName,
		CallType:     callType,
		CreatedBy:    createdBy,
		Participants: string(participantsJSON),
		StartedAt:    time.Now(),
		Status:       "pending",
		Duration:     0,
	}, nil
}

func (r *CallHistoryRepo) Update(callID string, endedAt time.Time, duration int, status string) error {
	// If endedAt is zero time, don't update it (for pending/rejected status)
	var err error
	if endedAt.IsZero() {
		_, err = r.db.conn.Exec(
			`UPDATE call_history SET duration_seconds = ?, status = ? WHERE call_id = ?`,
			duration, status, callID,
		)
	} else {
		_, err = r.db.conn.Exec(
			`UPDATE call_history SET ended_at = ?, duration_seconds = ?, status = ? WHERE call_id = ?`,
			endedAt, duration, status, callID,
		)
	}
	if err != nil {
		return fmt.Errorf("failed to update call history: %w", err)
	}
	return nil
}

func (r *CallHistoryRepo) GetByCallID(callID string) (*models.CallHistory, error) {
	var history models.CallHistory
	var endedAt sql.NullTime
	var invitationIDs sql.NullString
	err := r.db.conn.QueryRow(
		`SELECT id, call_id, room_name, call_type, created_by, participants, started_at, ended_at, duration_seconds, status, invitation_ids
		 FROM call_history WHERE call_id = ?`,
		callID,
	).Scan(&history.ID, &history.CallID, &history.RoomName, &history.CallType, &history.CreatedBy,
		&history.Participants, &history.StartedAt, &endedAt, &history.Duration, &history.Status, &invitationIDs)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get call history: %w", err)
	}

	if endedAt.Valid {
		history.EndedAt = &endedAt.Time
	}
	if invitationIDs.Valid {
		history.InvitationIDs = invitationIDs.String
	} else {
		history.InvitationIDs = ""
	}

	return &history, nil
}

func (r *CallHistoryRepo) GetByUserID(userID int64, limit, offset int) ([]*models.CallHistory, error) {
	// Try to get username for this userID to check participants
	// If lookup fails, fallback to created_by only query
	userRepo := NewUserRepo(r.db)
	user, err := userRepo.GetByID(userID)
	
	var rows *sql.Rows
	if err == nil && user != nil {
		// User found - query by created_by OR participant
		username := user.Username
		// Escape username for LIKE query (handle special characters)
		escapedUsername := "%\"" + username + "\"%"
		rows, err = r.db.conn.Query(
			`SELECT id, call_id, room_name, call_type, created_by, participants, started_at, ended_at, duration_seconds, status, invitation_ids
			 FROM call_history 
			 WHERE created_by = ? OR participants LIKE ? 
			 ORDER BY started_at DESC LIMIT ? OFFSET ?`,
			userID, escapedUsername, limit, offset,
		)
	} else {
		// User lookup failed - fallback to created_by only
		// This handles cases where user might not exist or lookup fails
		if err != nil {
			log.Printf("Warning: Failed to get user %d for call history query, falling back to created_by only: %v", userID, err)
		} else {
			log.Printf("Warning: User %d not found for call history query, falling back to created_by only", userID)
		}
		rows, err = r.db.conn.Query(
			`SELECT id, call_id, room_name, call_type, created_by, participants, started_at, ended_at, duration_seconds, status, invitation_ids
			 FROM call_history 
			 WHERE created_by = ? 
			 ORDER BY started_at DESC LIMIT ? OFFSET ?`,
			userID, limit, offset,
		)
	}
	if err != nil {
		log.Printf("Error querying call history for user %d: %v", userID, err)
		return nil, fmt.Errorf("failed to get call history: %w", err)
	}
	defer rows.Close()

	var histories []*models.CallHistory
	for rows.Next() {
		var history models.CallHistory
		var endedAt sql.NullTime
		var invitationIDs sql.NullString
		if err := rows.Scan(&history.ID, &history.CallID, &history.RoomName, &history.CallType, &history.CreatedBy,
			&history.Participants, &history.StartedAt, &endedAt, &history.Duration, &history.Status, &invitationIDs); err != nil {
			return nil, fmt.Errorf("failed to scan call history: %w", err)
		}
		if endedAt.Valid {
			history.EndedAt = &endedAt.Time
		}
		if invitationIDs.Valid {
			history.InvitationIDs = invitationIDs.String
		} else {
			history.InvitationIDs = ""
		}
		histories = append(histories, &history)
	}

	return histories, rows.Err()
}

func (r *CallHistoryRepo) GetByDateRange(userID int64, startDate, endDate time.Time) ([]*models.CallHistory, error) {
	// Try to get username for this userID to check participants
	// If lookup fails, fallback to created_by only query
	userRepo := NewUserRepo(r.db)
	user, err := userRepo.GetByID(userID)
	
	var rows *sql.Rows
	if err == nil && user != nil {
		// User found - query by created_by OR participant
		username := user.Username
		// Escape username for LIKE query (handle special characters)
		escapedUsername := "%\"" + username + "\"%"
		rows, err = r.db.conn.Query(
			`SELECT id, call_id, room_name, call_type, created_by, participants, started_at, ended_at, duration_seconds, status, invitation_ids
			 FROM call_history 
			 WHERE (created_by = ? OR participants LIKE ?) AND started_at >= ? AND started_at <= ? 
			 ORDER BY started_at DESC`,
			userID, escapedUsername, startDate, endDate,
		)
	} else {
		// User lookup failed - fallback to created_by only
		if err != nil {
			log.Printf("Warning: Failed to get user %d for call history date range query, falling back to created_by only: %v", userID, err)
		} else {
			log.Printf("Warning: User %d not found for call history date range query, falling back to created_by only", userID)
		}
		rows, err = r.db.conn.Query(
			`SELECT id, call_id, room_name, call_type, created_by, participants, started_at, ended_at, duration_seconds, status, invitation_ids
			 FROM call_history 
			 WHERE created_by = ? AND started_at >= ? AND started_at <= ? 
			 ORDER BY started_at DESC`,
			userID, startDate, endDate,
		)
	}
	if err != nil {
		log.Printf("Error querying call history by date range for user %d: %v", userID, err)
		return nil, fmt.Errorf("failed to get call history: %w", err)
	}
	defer rows.Close()

	var histories []*models.CallHistory
	for rows.Next() {
		var history models.CallHistory
		var endedAt sql.NullTime
		var invitationIDs sql.NullString
		if err := rows.Scan(&history.ID, &history.CallID, &history.RoomName, &history.CallType, &history.CreatedBy,
			&history.Participants, &history.StartedAt, &endedAt, &history.Duration, &history.Status, &invitationIDs); err != nil {
			return nil, fmt.Errorf("failed to scan call history: %w", err)
		}
		if endedAt.Valid {
			history.EndedAt = &endedAt.Time
		}
		if invitationIDs.Valid {
			history.InvitationIDs = invitationIDs.String
		} else {
			history.InvitationIDs = ""
		}
		histories = append(histories, &history)
	}

	return histories, rows.Err()
}

func (r *CallHistoryRepo) Delete(callID string) error {
	_, err := r.db.conn.Exec(`DELETE FROM call_history WHERE call_id = ?`, callID)
	if err != nil {
		return fmt.Errorf("failed to delete call history: %w", err)
	}
	return nil
}

