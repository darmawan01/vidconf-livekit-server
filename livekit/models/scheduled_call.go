package models

import "time"

type ScheduledCall struct {
	ID                int64      `json:"id"`
	CallID            string     `json:"callId"`
	RoomName          string     `json:"roomName"`
	CallType          string     `json:"callType"`
	CreatedBy         int64      `json:"createdBy"`
	ScheduledAt       time.Time  `json:"scheduledAt"`
	Timezone          string     `json:"timezone"`
	Recurrence        string     `json:"recurrence"` // JSON
	Title             string     `json:"title"`
	Description       string     `json:"description"`
	JoinLink          string     `json:"joinLink"`
	Status            string     `json:"status"` // "scheduled", "started", "completed", "cancelled"
	ReminderSentAt    *time.Time `json:"reminderSentAt,omitempty"`
	MaxParticipants   int        `json:"maxParticipants"`
	MaxDurationSeconds int       `json:"maxDurationSeconds"`
	Invitees          []string   `json:"invitees,omitempty"` // Populated from scheduled_call_invitations
	CreatedAt         time.Time  `json:"createdAt"`
	UpdatedAt         time.Time  `json:"updatedAt"`
}

type ScheduledCallInvitation struct {
	ID              int64      `json:"id"`
	ScheduledCallID int64      `json:"scheduledCallId"`
	InviteeID       int64      `json:"inviteeId"`
	Status          string     `json:"status"` // "pending", "accepted", "rejected"
	ReminderSentAt  *time.Time `json:"reminderSentAt,omitempty"`
	CreatedAt       time.Time  `json:"createdAt"`
}

