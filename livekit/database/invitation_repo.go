package database

import (
	"database/sql"
	"fmt"
	"livekit/models"
	"time"
)

type InvitationRepo struct {
	db *DB
}

func NewInvitationRepo(db *DB) *InvitationRepo {
	return &InvitationRepo{db: db}
}

func (r *InvitationRepo) Create(callID string, inviterID, inviteeID int64, callType, roomName string) (*models.Invitation, error) {
	result, err := r.db.conn.Exec(
		`INSERT INTO call_invitations (call_id, inviter_id, invitee_id, call_type, room_name, status, created_at)
		 VALUES (?, ?, ?, ?, ?, 'pending', ?)`,
		callID, inviterID, inviteeID, callType, roomName, time.Now(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create invitation: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("failed to get last insert id: %w", err)
	}

	var inviterUsername, inviteeUsername string
	err = r.db.conn.QueryRow("SELECT username FROM users WHERE id = ?", inviterID).Scan(&inviterUsername)
	if err != nil {
		return nil, fmt.Errorf("failed to get inviter username: %w", err)
	}

	err = r.db.conn.QueryRow("SELECT username FROM users WHERE id = ?", inviteeID).Scan(&inviteeUsername)
	if err != nil {
		return nil, fmt.Errorf("failed to get invitee username: %w", err)
	}

	return &models.Invitation{
		ID:        id,
		CallID:    callID,
		InviterID: inviterID,
		Inviter:   inviterUsername,
		InviteeID: inviteeID,
		Invitee:   inviteeUsername,
		CallType:  callType,
		RoomName:  roomName,
		Status:    "pending",
		CreatedAt: time.Now(),
	}, nil
}

func (r *InvitationRepo) GetPendingForUser(userID int64) ([]*models.Invitation, error) {
	rows, err := r.db.conn.Query(
		`SELECT ci.id, ci.call_id, ci.inviter_id, u1.username, ci.invitee_id, u2.username,
		        ci.call_type, ci.room_name, ci.status, ci.created_at, ci.responded_at
		 FROM call_invitations ci
		 JOIN users u1 ON ci.inviter_id = u1.id
		 JOIN users u2 ON ci.invitee_id = u2.id
		 WHERE ci.invitee_id = ? AND ci.status = 'pending'
		 ORDER BY ci.created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get pending invitations: %w", err)
	}
	defer rows.Close()

	var invitations []*models.Invitation
	for rows.Next() {
		var inv models.Invitation
		var respondedAt sql.NullTime
		if err := rows.Scan(&inv.ID, &inv.CallID, &inv.InviterID, &inv.Inviter, &inv.InviteeID, &inv.Invitee,
			&inv.CallType, &inv.RoomName, &inv.Status, &inv.CreatedAt, &respondedAt); err != nil {
			return nil, fmt.Errorf("failed to scan invitation: %w", err)
		}
		if respondedAt.Valid {
			inv.RespondedAt = &respondedAt.Time
		}
		invitations = append(invitations, &inv)
	}

	return invitations, rows.Err()
}

func (r *InvitationRepo) UpdateStatus(invitationID int64, status string) error {
	var respondedAt interface{}
	if status == "accepted" || status == "rejected" {
		respondedAt = time.Now()
	}

	_, err := r.db.conn.Exec(
		"UPDATE call_invitations SET status = ?, responded_at = ? WHERE id = ?",
		status, respondedAt, invitationID,
	)
	if err != nil {
		return fmt.Errorf("failed to update invitation status: %w", err)
	}

	return nil
}

func (r *InvitationRepo) GetByID(invitationID int64) (*models.Invitation, error) {
	var inv models.Invitation
	var respondedAt sql.NullTime
	err := r.db.conn.QueryRow(
		`SELECT ci.id, ci.call_id, ci.inviter_id, u1.username, ci.invitee_id, u2.username,
		        ci.call_type, ci.room_name, ci.status, ci.created_at, ci.responded_at
		 FROM call_invitations ci
		 JOIN users u1 ON ci.inviter_id = u1.id
		 JOIN users u2 ON ci.invitee_id = u2.id
		 WHERE ci.id = ?`,
		invitationID,
	).Scan(&inv.ID, &inv.CallID, &inv.InviterID, &inv.Inviter, &inv.InviteeID, &inv.Invitee,
		&inv.CallType, &inv.RoomName, &inv.Status, &inv.CreatedAt, &respondedAt)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get invitation: %w", err)
	}

	if respondedAt.Valid {
		inv.RespondedAt = &respondedAt.Time
	}

	return &inv, nil
}

func (r *InvitationRepo) GetCallParticipants(callID string) ([]*models.Invitation, error) {
	rows, err := r.db.conn.Query(
		`SELECT ci.id, ci.call_id, ci.inviter_id, u1.username, ci.invitee_id, u2.username,
		        ci.call_type, ci.room_name, ci.status, ci.created_at, ci.responded_at
		 FROM call_invitations ci
		 JOIN users u1 ON ci.inviter_id = u1.id
		 JOIN users u2 ON ci.invitee_id = u2.id
		 WHERE ci.call_id = ?
		 ORDER BY ci.created_at ASC`,
		callID,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get call participants: %w", err)
	}
	defer rows.Close()

	var invitations []*models.Invitation
	for rows.Next() {
		var inv models.Invitation
		var respondedAt sql.NullTime
		if err := rows.Scan(&inv.ID, &inv.CallID, &inv.InviterID, &inv.Inviter, &inv.InviteeID, &inv.Invitee,
			&inv.CallType, &inv.RoomName, &inv.Status, &inv.CreatedAt, &respondedAt); err != nil {
			return nil, fmt.Errorf("failed to scan invitation: %w", err)
		}
		if respondedAt.Valid {
			inv.RespondedAt = &respondedAt.Time
		}
		invitations = append(invitations, &inv)
	}

	return invitations, rows.Err()
}

