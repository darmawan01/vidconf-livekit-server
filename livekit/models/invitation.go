package models

import "time"

type Invitation struct {
	ID          int64      `json:"id"`
	CallID      string     `json:"callId"`
	InviterID   int64      `json:"inviterId"`
	Inviter     string     `json:"inviter"`
	InviteeID   int64      `json:"inviteeId"`
	Invitee     string     `json:"invitee"`
	CallType    string     `json:"callType"`
	RoomName    string     `json:"roomName"`
	Status      string     `json:"status"`
	CreatedAt   time.Time  `json:"createdAt"`
	RespondedAt *time.Time `json:"respondedAt,omitempty"`
}


