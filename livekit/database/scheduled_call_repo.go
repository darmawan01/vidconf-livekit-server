package database

import (
	"database/sql"
	"fmt"
	"livekit/models"
	"time"
)

type ScheduledCallRepo struct {
	db *DB
}

func NewScheduledCallRepo(db *DB) *ScheduledCallRepo {
	return &ScheduledCallRepo{db: db}
}

func (r *ScheduledCallRepo) Create(callID, roomName, callType string, createdBy int64, scheduledAt time.Time, timezone, recurrence, title, description, joinLink string, maxParticipants, maxDurationSeconds int) (*models.ScheduledCall, error) {
	result, err := r.db.conn.Exec(
		`INSERT INTO scheduled_calls (call_id, room_name, call_type, created_by, scheduled_at, timezone, recurrence_pattern, title, description, join_link, status, max_participants, max_duration_seconds, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'scheduled', ?, ?, ?, ?)`,
		callID, roomName, callType, createdBy, scheduledAt, timezone, recurrence, title, description, joinLink, maxParticipants, maxDurationSeconds, time.Now(), time.Now(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create scheduled call: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("failed to get last insert id: %w", err)
	}

	return &models.ScheduledCall{
		ID:                id,
		CallID:            callID,
		RoomName:          roomName,
		CallType:          callType,
		CreatedBy:         createdBy,
		ScheduledAt:       scheduledAt,
		Timezone:          timezone,
		Recurrence:        recurrence,
		Title:             title,
		Description:       description,
		JoinLink:          joinLink,
		Status:            "scheduled",
		MaxParticipants:   maxParticipants,
		MaxDurationSeconds: maxDurationSeconds,
		CreatedAt:         time.Now(),
		UpdatedAt:         time.Now(),
	}, nil
}

func (r *ScheduledCallRepo) GetByID(id int64) (*models.ScheduledCall, error) {
	var call models.ScheduledCall
	var reminderSentAt sql.NullTime
	err := r.db.conn.QueryRow(
		`SELECT id, call_id, room_name, call_type, created_by, scheduled_at, timezone, recurrence_pattern, title, description, join_link, status, reminder_sent_at, max_participants, max_duration_seconds, created_at, updated_at
		 FROM scheduled_calls WHERE id = ?`,
		id,
	).Scan(&call.ID, &call.CallID, &call.RoomName, &call.CallType, &call.CreatedBy, &call.ScheduledAt, &call.Timezone,
		&call.Recurrence, &call.Title, &call.Description, &call.JoinLink, &call.Status, &reminderSentAt, &call.MaxParticipants, &call.MaxDurationSeconds, &call.CreatedAt, &call.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get scheduled call: %w", err)
	}

	if reminderSentAt.Valid {
		call.ReminderSentAt = &reminderSentAt.Time
	}

	return &call, nil
}

func (r *ScheduledCallRepo) GetByUserID(userID int64, status string) ([]*models.ScheduledCall, error) {
	var rows *sql.Rows
	var err error

	if status != "" {
		rows, err = r.db.conn.Query(
			`SELECT id, call_id, room_name, call_type, created_by, scheduled_at, timezone, recurrence_pattern, title, description, join_link, status, reminder_sent_at, max_participants, max_duration_seconds, created_at, updated_at
			 FROM scheduled_calls WHERE created_by = ? AND status = ? ORDER BY scheduled_at ASC`,
			userID, status,
		)
	} else {
		rows, err = r.db.conn.Query(
			`SELECT id, call_id, room_name, call_type, created_by, scheduled_at, timezone, recurrence_pattern, title, description, join_link, status, reminder_sent_at, max_participants, max_duration_seconds, created_at, updated_at
			 FROM scheduled_calls WHERE created_by = ? ORDER BY scheduled_at ASC`,
			userID,
		)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to get scheduled calls: %w", err)
	}
	defer rows.Close()

	var calls []*models.ScheduledCall
	for rows.Next() {
		var call models.ScheduledCall
		var reminderSentAt sql.NullTime
		if err := rows.Scan(&call.ID, &call.CallID, &call.RoomName, &call.CallType, &call.CreatedBy, &call.ScheduledAt, &call.Timezone,
			&call.Recurrence, &call.Title, &call.Description, &call.JoinLink, &call.Status, &reminderSentAt, &call.MaxParticipants, &call.MaxDurationSeconds, &call.CreatedAt, &call.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan scheduled call: %w", err)
		}
		if reminderSentAt.Valid {
			call.ReminderSentAt = &reminderSentAt.Time
		}
		calls = append(calls, &call)
	}

	return calls, rows.Err()
}

func (r *ScheduledCallRepo) GetUpcoming(limit int) ([]*models.ScheduledCall, error) {
	rows, err := r.db.conn.Query(
		`SELECT id, call_id, room_name, call_type, created_by, scheduled_at, timezone, recurrence_pattern, title, description, join_link, status, reminder_sent_at, max_participants, max_duration_seconds, created_at, updated_at
		 FROM scheduled_calls WHERE status = 'scheduled' AND scheduled_at >= ? ORDER BY scheduled_at ASC LIMIT ?`,
		time.Now(), limit,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get upcoming scheduled calls: %w", err)
	}
	defer rows.Close()

	var calls []*models.ScheduledCall
	for rows.Next() {
		var call models.ScheduledCall
		var reminderSentAt sql.NullTime
		if err := rows.Scan(&call.ID, &call.CallID, &call.RoomName, &call.CallType, &call.CreatedBy, &call.ScheduledAt, &call.Timezone,
			&call.Recurrence, &call.Title, &call.Description, &call.JoinLink, &call.Status, &reminderSentAt, &call.MaxParticipants, &call.MaxDurationSeconds, &call.CreatedAt, &call.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan scheduled call: %w", err)
		}
		if reminderSentAt.Valid {
			call.ReminderSentAt = &reminderSentAt.Time
		}
		calls = append(calls, &call)
	}

	return calls, rows.Err()
}

func (r *ScheduledCallRepo) UpdateStatus(id int64, status string) error {
	_, err := r.db.conn.Exec(
		`UPDATE scheduled_calls SET status = ?, updated_at = ? WHERE id = ?`,
		status, time.Now(), id,
	)
	if err != nil {
		return fmt.Errorf("failed to update scheduled call status: %w", err)
	}
	return nil
}

func (r *ScheduledCallRepo) UpdateReminderSent(id int64) error {
	_, err := r.db.conn.Exec(
		`UPDATE scheduled_calls SET reminder_sent_at = ? WHERE id = ?`,
		time.Now(), id,
	)
	if err != nil {
		return fmt.Errorf("failed to update reminder sent: %w", err)
	}
	return nil
}

func (r *ScheduledCallRepo) Delete(id int64) error {
	_, err := r.db.conn.Exec(`DELETE FROM scheduled_calls WHERE id = ?`, id)
	if err != nil {
		return fmt.Errorf("failed to delete scheduled call: %w", err)
	}
	return nil
}

// GetByInviteeID returns scheduled calls where the user is an invitee
func (r *ScheduledCallRepo) GetByInviteeID(inviteeID int64, status string) ([]*models.ScheduledCall, error) {
	var rows *sql.Rows
	var err error

	query := `
		SELECT sc.id, sc.call_id, sc.room_name, sc.call_type, sc.created_by, sc.scheduled_at, 
		       sc.timezone, sc.recurrence_pattern, sc.title, sc.description, sc.join_link, 
		       sc.status, sc.reminder_sent_at, sc.max_participants, sc.max_duration_seconds, 
		       sc.created_at, sc.updated_at
		FROM scheduled_calls sc
		INNER JOIN scheduled_call_invitations sci ON sc.id = sci.scheduled_call_id
		WHERE sci.invitee_id = ?`

	if status != "" {
		query += " AND sc.status = ?"
		query += " ORDER BY sc.scheduled_at ASC"
		rows, err = r.db.conn.Query(query, inviteeID, status)
	} else {
		query += " ORDER BY sc.scheduled_at ASC"
		rows, err = r.db.conn.Query(query, inviteeID)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to get scheduled calls for invitee: %w", err)
	}
	defer rows.Close()

	var calls []*models.ScheduledCall
	for rows.Next() {
		var call models.ScheduledCall
		var reminderSentAt sql.NullTime
		if err := rows.Scan(&call.ID, &call.CallID, &call.RoomName, &call.CallType, &call.CreatedBy, &call.ScheduledAt, &call.Timezone,
			&call.Recurrence, &call.Title, &call.Description, &call.JoinLink, &call.Status, &reminderSentAt, &call.MaxParticipants, &call.MaxDurationSeconds, &call.CreatedAt, &call.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan scheduled call: %w", err)
		}
		if reminderSentAt.Valid {
			call.ReminderSentAt = &reminderSentAt.Time
		}
		calls = append(calls, &call)
	}

	return calls, rows.Err()
}

