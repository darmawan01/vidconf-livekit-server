package database

import (
	"database/sql"
	"fmt"
	"livekit/models"
	"time"
)

type CallRepo struct {
	db *DB
}

func NewCallRepo(db *DB) *CallRepo {
	return &CallRepo{db: db}
}

func (r *CallRepo) Create(callID, roomName, callType string, createdBy int64) (*models.ActiveCall, error) {
	result, err := r.db.conn.Exec(
		`INSERT INTO active_calls (call_id, room_name, call_type, created_by, status, created_at)
		 VALUES (?, ?, ?, ?, 'active', ?)`,
		callID, roomName, callType, createdBy, time.Now(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create call: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("failed to get last insert id: %w", err)
	}

	return &models.ActiveCall{
		ID:        id,
		CallID:    callID,
		RoomName:  roomName,
		CallType:  callType,
		CreatedBy: createdBy,
		Status:    "active",
		CreatedAt: time.Now(),
	}, nil
}

func (r *CallRepo) GetByCallID(callID string) (*models.ActiveCall, error) {
	var call models.ActiveCall
	var endedAt sql.NullTime
	err := r.db.conn.QueryRow(
		"SELECT id, call_id, room_name, call_type, created_by, created_at, ended_at, status FROM active_calls WHERE call_id = ?",
		callID,
	).Scan(&call.ID, &call.CallID, &call.RoomName, &call.CallType, &call.CreatedBy, &call.CreatedAt, &endedAt, &call.Status)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get call: %w", err)
	}

	if endedAt.Valid {
		call.EndedAt = &endedAt.Time
	}

	return &call, nil
}

func (r *CallRepo) GetByRoomName(roomName string) (*models.ActiveCall, error) {
	var call models.ActiveCall
	var endedAt sql.NullTime
	err := r.db.conn.QueryRow(
		"SELECT id, call_id, room_name, call_type, created_by, created_at, ended_at, status FROM active_calls WHERE room_name = ?",
		roomName,
	).Scan(&call.ID, &call.CallID, &call.RoomName, &call.CallType, &call.CreatedBy, &call.CreatedAt, &endedAt, &call.Status)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get call: %w", err)
	}

	if endedAt.Valid {
		call.EndedAt = &endedAt.Time
	}

	return &call, nil
}

func (r *CallRepo) UpdateStatus(callID, status string) error {
	var endedAt interface{}
	if status == "ended" {
		endedAt = time.Now()
	}

	_, err := r.db.conn.Exec(
		"UPDATE active_calls SET status = ?, ended_at = ? WHERE call_id = ?",
		status, endedAt, callID,
	)
	if err != nil {
		return fmt.Errorf("failed to update call status: %w", err)
	}

	return nil
}

func (r *CallRepo) GetActiveCalls() ([]*models.ActiveCall, error) {
	rows, err := r.db.conn.Query(
		"SELECT id, call_id, room_name, call_type, created_by, created_at, ended_at, status FROM active_calls WHERE status = 'active' ORDER BY created_at DESC",
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get active calls: %w", err)
	}
	defer rows.Close()

	var calls []*models.ActiveCall
	for rows.Next() {
		var call models.ActiveCall
		var endedAt sql.NullTime
		if err := rows.Scan(&call.ID, &call.CallID, &call.RoomName, &call.CallType, &call.CreatedBy, &call.CreatedAt, &endedAt, &call.Status); err != nil {
			return nil, fmt.Errorf("failed to scan call: %w", err)
		}
		if endedAt.Valid {
			call.EndedAt = &endedAt.Time
		}
		calls = append(calls, &call)
	}

	return calls, rows.Err()
}


