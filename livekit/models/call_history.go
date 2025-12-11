package models

import "time"

type CallHistory struct {
	ID            int64      `json:"id"`
	CallID        string     `json:"callId"`
	RoomName      string     `json:"roomName"`
	CallType      string     `json:"callType"`
	CreatedBy     int64      `json:"createdBy"`
	Participants  string     `json:"participants"` // JSON array of usernames
	StartedAt     time.Time  `json:"startedAt"`
	EndedAt       *time.Time `json:"endedAt,omitempty"`
	Duration      int        `json:"durationSeconds"`
	Status        string     `json:"status"` // "completed", "missed", "rejected"
	InvitationIDs string     `json:"invitationIds,omitempty"` // JSON array of invitation IDs
}

