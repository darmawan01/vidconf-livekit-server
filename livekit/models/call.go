package models

import "time"

type ActiveCall struct {
	ID        int64      `json:"id"`
	CallID    string     `json:"callId"`
	RoomName  string     `json:"roomName"`
	CallType  string     `json:"callType"`
	CreatedBy int64      `json:"createdBy"`
	CreatedAt time.Time  `json:"createdAt"`
	EndedAt   *time.Time `json:"endedAt,omitempty"`
	Status    string     `json:"status"`
}


