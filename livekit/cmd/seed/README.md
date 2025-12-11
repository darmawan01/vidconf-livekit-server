# Database Seeder

This seeder populates the database with sample users and contacts for development and testing.

## Usage

```bash
cd livekit
go run ./cmd/seed
```

Or build and run:

```bash
cd livekit
go build ./cmd/seed
./seed
```

## What it seeds

- **5 test users**: alice, bob, charlie, diana, eve (all with password: `password123`)
- **Bidirectional contacts** between users for testing call invitations

## Notes

- The seeder is idempotent - it won't create duplicate users or contacts
- Existing users are skipped if they already exist
- All passwords are hashed using bcrypt

