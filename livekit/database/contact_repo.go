package database

import (
	"fmt"
	"livekit/models"
)

type ContactRepo struct {
	db *DB
}

func NewContactRepo(db *DB) *ContactRepo {
	return &ContactRepo{db: db}
}

func (r *ContactRepo) Add(userID, contactUserID int64) error {
	tx, err := r.db.BeginTx()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	_, err = tx.Exec(
		"INSERT OR IGNORE INTO contacts (user_id, contact_user_id) VALUES (?, ?)",
		userID, contactUserID,
	)
	if err != nil {
		return fmt.Errorf("failed to add contact: %w", err)
	}

	_, err = tx.Exec(
		"INSERT OR IGNORE INTO contacts (user_id, contact_user_id) VALUES (?, ?)",
		contactUserID, userID,
	)
	if err != nil {
		return fmt.Errorf("failed to add bidirectional contact: %w", err)
	}

	return tx.Commit()
}

func (r *ContactRepo) GetUserContacts(userID int64) ([]*models.Contact, error) {
	rows, err := r.db.conn.Query(
		`SELECT c.id, c.user_id, c.contact_user_id, u.username, c.created_at
		 FROM contacts c
		 JOIN users u ON c.contact_user_id = u.id
		 WHERE c.user_id = ?
		 ORDER BY c.created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get contacts: %w", err)
	}
	defer rows.Close()

	var contacts []*models.Contact
	for rows.Next() {
		var contact models.Contact
		if err := rows.Scan(&contact.ID, &contact.UserID, &contact.ContactID, &contact.Username, &contact.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan contact: %w", err)
		}
		contacts = append(contacts, &contact)
	}

	return contacts, rows.Err()
}

func (r *ContactRepo) Remove(userID, contactUserID int64) error {
	tx, err := r.db.BeginTx()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	_, err = tx.Exec(
		"DELETE FROM contacts WHERE user_id = ? AND contact_user_id = ?",
		userID, contactUserID,
	)
	if err != nil {
		return fmt.Errorf("failed to remove contact: %w", err)
	}

	_, err = tx.Exec(
		"DELETE FROM contacts WHERE user_id = ? AND contact_user_id = ?",
		contactUserID, userID,
	)
	if err != nil {
		return fmt.Errorf("failed to remove bidirectional contact: %w", err)
	}

	return tx.Commit()
}

func (r *ContactRepo) Exists(userID, contactUserID int64) (bool, error) {
	var count int
	err := r.db.conn.QueryRow(
		"SELECT COUNT(*) FROM contacts WHERE user_id = ? AND contact_user_id = ?",
		userID, contactUserID,
	).Scan(&count)

	if err != nil {
		return false, fmt.Errorf("failed to check contact existence: %w", err)
	}

	return count > 0, nil
}

func (r *ContactRepo) Search(userID int64, query string) ([]*models.Contact, error) {
	rows, err := r.db.conn.Query(
		`SELECT c.id, c.user_id, c.contact_user_id, u.username, c.created_at
		 FROM contacts c
		 JOIN users u ON c.contact_user_id = u.id
		 WHERE c.user_id = ? AND u.username LIKE ?
		 ORDER BY c.created_at DESC`,
		userID, "%"+query+"%",
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search contacts: %w", err)
	}
	defer rows.Close()

	var contacts []*models.Contact
	for rows.Next() {
		var contact models.Contact
		if err := rows.Scan(&contact.ID, &contact.UserID, &contact.ContactID, &contact.Username, &contact.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan contact: %w", err)
		}
		contacts = append(contacts, &contact)
	}

	return contacts, rows.Err()
}


