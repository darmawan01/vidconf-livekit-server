package database

import (
	"database/sql"
	"fmt"
	"livekit/models"
	"time"
)

type UserRepo struct {
	db *DB
}

func NewUserRepo(db *DB) *UserRepo {
	return &UserRepo{db: db}
}

func (r *UserRepo) Create(username, passwordHash string) (*models.User, error) {
	result, err := r.db.conn.Exec(
		"INSERT INTO users (username, password_hash, created_at, updated_at) VALUES (?, ?, ?, ?)",
		username, passwordHash, time.Now(), time.Now(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("failed to get last insert id: %w", err)
	}

	return &models.User{
		ID:        id,
		Username:  username,
		CreatedAt: time.Now(),
	}, nil
}

func (r *UserRepo) GetByUsername(username string) (*models.UserWithPassword, error) {
	var user models.UserWithPassword
	err := r.db.conn.QueryRow(
		"SELECT id, username, password_hash, created_at, updated_at FROM users WHERE username = ?",
		username,
	).Scan(&user.ID, &user.Username, &user.PasswordHash, &user.CreatedAt, &user.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

func (r *UserRepo) GetByID(id int64) (*models.User, error) {
	var user models.User
	err := r.db.conn.QueryRow(
		"SELECT id, username, created_at FROM users WHERE id = ?",
		id,
	).Scan(&user.ID, &user.Username, &user.CreatedAt)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

func (r *UserRepo) Exists(username string) (bool, error) {
	var count int
	err := r.db.conn.QueryRow(
		"SELECT COUNT(*) FROM users WHERE username = ?",
		username,
	).Scan(&count)

	if err != nil {
		return false, fmt.Errorf("failed to check user existence: %w", err)
	}

	return count > 0, nil
}


