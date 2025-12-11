package database

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"

	_ "github.com/mattn/go-sqlite3"
)

type DB struct {
	conn *sql.DB
}

func NewDB() (*DB, error) {
	dbPath := os.Getenv("DB_PATH")
	if dbPath == "" {
		dbPath = "vidconf.db"
	}

	dir := filepath.Dir(dbPath)
	if dir != "." && dir != "" {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return nil, fmt.Errorf("failed to create database directory: %w", err)
		}
	}

	conn, err := sql.Open("sqlite3", dbPath+"?_foreign_keys=1")
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	if err := conn.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	db := &DB{conn: conn}

	if err := db.migrate(); err != nil {
		return nil, fmt.Errorf("failed to migrate database: %w", err)
	}

	return db, nil
}

func (db *DB) migrate() error {
	tables := []string{
		createUsersTable,
		createContactsTable,
		createCallInvitationsTable,
		createActiveCallsTable,
		createCallHistoryTable,
		createScheduledCallsTable,
		createScheduledCallInvitationsTable,
		createIndexes,
	}

	for _, table := range tables {
		if _, err := db.conn.Exec(table); err != nil {
			return fmt.Errorf("failed to create table: %w", err)
		}
	}

	if err := db.migrateScheduledCalls(); err != nil {
		return fmt.Errorf("failed to migrate scheduled_calls: %w", err)
	}

	return nil
}

func (db *DB) migrateScheduledCalls() error {
	migrations := []string{
		`ALTER TABLE scheduled_calls ADD COLUMN max_participants INTEGER DEFAULT 0`,
		`ALTER TABLE scheduled_calls ADD COLUMN max_duration_seconds INTEGER DEFAULT 0`,
	}

	for _, migration := range migrations {
		_, err := db.conn.Exec(migration)
		if err != nil {
			msg := err.Error()
			if !contains(msg, "duplicate column name") {
				return fmt.Errorf("failed to execute migration: %w", err)
			}
		}
	}

	return nil
}

func contains(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

func (db *DB) Close() error {
	return db.conn.Close()
}

func (db *DB) Conn() *sql.DB {
	return db.conn
}

func (db *DB) BeginTx() (*sql.Tx, error) {
	return db.conn.Begin()
}


