package models

import "time"

type Contact struct {
	ID        int64     `json:"id"`
	UserID    int64     `json:"userId"`
	ContactID int64     `json:"contactId"`
	Username  string    `json:"username"`
	CreatedAt time.Time `json:"createdAt"`
}


