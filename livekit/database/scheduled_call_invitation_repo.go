package database

import (
	"database/sql"
	"fmt"
	"livekit/models"
	"time"
)

type ScheduledCallInvitationRepo struct {
	db *DB
}

func NewScheduledCallInvitationRepo(db *DB) *ScheduledCallInvitationRepo {
	return &ScheduledCallInvitationRepo{db: db}
}

func (r *ScheduledCallInvitationRepo) Create(scheduledCallID, inviteeID int64) (*models.ScheduledCallInvitation, error) {
	result, err := r.db.conn.Exec(
		`INSERT INTO scheduled_call_invitations (scheduled_call_id, invitee_id, status, created_at)
		 VALUES (?, ?, 'pending', ?)`,
		scheduledCallID, inviteeID, time.Now(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create scheduled call invitation: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("failed to get last insert id: %w", err)
	}

	return &models.ScheduledCallInvitation{
		ID:              id,
		ScheduledCallID: scheduledCallID,
		InviteeID:       inviteeID,
		Status:          "pending",
		CreatedAt:       time.Now(),
	}, nil
}

func (r *ScheduledCallInvitationRepo) GetByScheduledCallID(scheduledCallID int64) ([]*models.ScheduledCallInvitation, error) {
	rows, err := r.db.conn.Query(
		`SELECT id, scheduled_call_id, invitee_id, status, reminder_sent_at, created_at
		 FROM scheduled_call_invitations WHERE scheduled_call_id = ?`,
		scheduledCallID,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get scheduled call invitations: %w", err)
	}
	defer rows.Close()

	var invitations []*models.ScheduledCallInvitation
	for rows.Next() {
		var inv models.ScheduledCallInvitation
		var reminderSentAt sql.NullTime
		if err := rows.Scan(&inv.ID, &inv.ScheduledCallID, &inv.InviteeID, &inv.Status, &reminderSentAt, &inv.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan scheduled call invitation: %w", err)
		}
		if reminderSentAt.Valid {
			inv.ReminderSentAt = &reminderSentAt.Time
		}
		invitations = append(invitations, &inv)
	}

	return invitations, rows.Err()
}

func (r *ScheduledCallInvitationRepo) UpdateStatus(id int64, status string) error {
	_, err := r.db.conn.Exec(
		`UPDATE scheduled_call_invitations SET status = ? WHERE id = ?`,
		status, id,
	)
	if err != nil {
		return fmt.Errorf("failed to update scheduled call invitation status: %w", err)
	}
	return nil
}

func (r *ScheduledCallInvitationRepo) UpdateReminderSent(id int64) error {
	_, err := r.db.conn.Exec(
		`UPDATE scheduled_call_invitations SET reminder_sent_at = ? WHERE id = ?`,
		time.Now(), id,
	)
	if err != nil {
		return fmt.Errorf("failed to update reminder sent: %w", err)
	}
	return nil
}

