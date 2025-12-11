package database

const (
	createUsersTable = `
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE NOT NULL,
		password_hash TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);`

	createContactsTable = `
	CREATE TABLE IF NOT EXISTS contacts (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		contact_user_id INTEGER NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		UNIQUE(user_id, contact_user_id),
		FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
		FOREIGN KEY (contact_user_id) REFERENCES users(id) ON DELETE CASCADE
	);`

	createCallInvitationsTable = `
	CREATE TABLE IF NOT EXISTS call_invitations (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		call_id TEXT NOT NULL,
		inviter_id INTEGER NOT NULL,
		invitee_id INTEGER NOT NULL,
		call_type TEXT NOT NULL,
		room_name TEXT NOT NULL,
		status TEXT NOT NULL DEFAULT 'pending',
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		responded_at DATETIME,
		FOREIGN KEY (inviter_id) REFERENCES users(id) ON DELETE CASCADE,
		FOREIGN KEY (invitee_id) REFERENCES users(id) ON DELETE CASCADE
	);`

	createActiveCallsTable = `
	CREATE TABLE IF NOT EXISTS active_calls (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		call_id TEXT UNIQUE NOT NULL,
		room_name TEXT UNIQUE NOT NULL,
		call_type TEXT NOT NULL,
		created_by INTEGER NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		ended_at DATETIME,
		status TEXT NOT NULL DEFAULT 'active',
		duration_limit_seconds INTEGER,
		max_duration_seconds INTEGER,
		FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
	);`

	createCallHistoryTable = `
	CREATE TABLE IF NOT EXISTS call_history (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		call_id TEXT NOT NULL,
		room_name TEXT NOT NULL,
		call_type TEXT NOT NULL,
		created_by INTEGER NOT NULL,
		participants TEXT NOT NULL,
		started_at DATETIME NOT NULL,
		ended_at DATETIME,
		duration_seconds INTEGER DEFAULT 0,
		status TEXT NOT NULL DEFAULT 'completed',
		invitation_ids TEXT,
		FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
	);`

	createScheduledCallsTable = `
	CREATE TABLE IF NOT EXISTS scheduled_calls (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		call_id TEXT UNIQUE NOT NULL,
		room_name TEXT UNIQUE NOT NULL,
		call_type TEXT NOT NULL,
		created_by INTEGER NOT NULL,
		scheduled_at DATETIME NOT NULL,
		timezone TEXT NOT NULL DEFAULT 'UTC',
		recurrence_pattern TEXT,
		title TEXT,
		description TEXT,
		join_link TEXT,
		status TEXT NOT NULL DEFAULT 'scheduled',
		reminder_sent_at DATETIME,
		max_participants INTEGER DEFAULT 0,
		max_duration_seconds INTEGER DEFAULT 0,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
	);`

	createScheduledCallInvitationsTable = `
	CREATE TABLE IF NOT EXISTS scheduled_call_invitations (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		scheduled_call_id INTEGER NOT NULL,
		invitee_id INTEGER NOT NULL,
		status TEXT NOT NULL DEFAULT 'pending',
		reminder_sent_at DATETIME,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (scheduled_call_id) REFERENCES scheduled_calls(id) ON DELETE CASCADE,
		FOREIGN KEY (invitee_id) REFERENCES users(id) ON DELETE CASCADE,
		UNIQUE(scheduled_call_id, invitee_id)
	);`

	createIndexes = `
	CREATE INDEX IF NOT EXISTS idx_contacts_user_id ON contacts(user_id);
	CREATE INDEX IF NOT EXISTS idx_contacts_contact_user_id ON contacts(contact_user_id);
	CREATE INDEX IF NOT EXISTS idx_call_invitations_call_id ON call_invitations(call_id);
	CREATE INDEX IF NOT EXISTS idx_call_invitations_invitee_id ON call_invitations(invitee_id);
	CREATE INDEX IF NOT EXISTS idx_call_invitations_status ON call_invitations(status);
	CREATE INDEX IF NOT EXISTS idx_active_calls_call_id ON active_calls(call_id);
	CREATE INDEX IF NOT EXISTS idx_active_calls_status ON active_calls(status);
	CREATE INDEX IF NOT EXISTS idx_call_history_call_id ON call_history(call_id);
	CREATE INDEX IF NOT EXISTS idx_call_history_created_by ON call_history(created_by);
	CREATE INDEX IF NOT EXISTS idx_call_history_started_at ON call_history(started_at);
	CREATE INDEX IF NOT EXISTS idx_scheduled_calls_call_id ON scheduled_calls(call_id);
	CREATE INDEX IF NOT EXISTS idx_scheduled_calls_created_by ON scheduled_calls(created_by);
	CREATE INDEX IF NOT EXISTS idx_scheduled_calls_scheduled_at ON scheduled_calls(scheduled_at);
	CREATE INDEX IF NOT EXISTS idx_scheduled_calls_status ON scheduled_calls(status);
	CREATE INDEX IF NOT EXISTS idx_scheduled_call_invitations_scheduled_call_id ON scheduled_call_invitations(scheduled_call_id);
	CREATE INDEX IF NOT EXISTS idx_scheduled_call_invitations_invitee_id ON scheduled_call_invitations(invitee_id);
	`
)


