package main

import (
	"fmt"
	"livekit/database"
	"log"

	"golang.org/x/crypto/bcrypt"
)

func main() {
	db, err := database.NewDB()
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()

	log.Println("Starting database seeding...")

	userRepo := database.NewUserRepo(db)
	contactRepo := database.NewContactRepo(db)

	users := []struct {
		username string
		password string
	}{
		{"alice", "password123"},
		{"bob", "password123"},
		{"charlie", "password123"},
		{"diana", "password123"},
		{"eve", "password123"},
	}

	var createdUsers []int64

	for _, u := range users {
		passwordHash, err := bcrypt.GenerateFromPassword([]byte(u.password), bcrypt.DefaultCost)
		if err != nil {
			log.Fatalf("Failed to hash password for %s: %v", u.username, err)
		}

		existingUser, _ := userRepo.GetByUsername(u.username)
		if existingUser != nil {
			log.Printf("User %s already exists, skipping...", u.username)
			createdUsers = append(createdUsers, existingUser.ID)
			continue
		}

		user, err := userRepo.Create(u.username, string(passwordHash))
		if err != nil {
			log.Fatalf("Failed to create user %s: %v", u.username, err)
		}

		createdUsers = append(createdUsers, user.ID)
		log.Printf("Created user: %s (ID: %d)", u.username, user.ID)
	}

	if len(createdUsers) < 2 {
		log.Println("Not enough users to create contacts")
		return
	}

	contacts := []struct {
		userID   int64
		contactID int64
	}{
		{createdUsers[0], createdUsers[1]},
		{createdUsers[0], createdUsers[2]},
		{createdUsers[1], createdUsers[0]},
		{createdUsers[1], createdUsers[2]},
		{createdUsers[2], createdUsers[0]},
		{createdUsers[2], createdUsers[1]},
		{createdUsers[3], createdUsers[4]},
		{createdUsers[4], createdUsers[3]},
	}

	for _, c := range contacts {
		exists, err := contactRepo.Exists(c.userID, c.contactID)
		if err != nil {
			log.Printf("Error checking contact existence: %v", err)
			continue
		}
		if exists {
			log.Printf("Contact between user %d and %d already exists, skipping...", c.userID, c.contactID)
			continue
		}

		err = contactRepo.Add(c.userID, c.contactID)
		if err != nil {
			log.Printf("Failed to create contact: %v", err)
			continue
		}
		log.Printf("Created contact: user %d <-> user %d", c.userID, c.contactID)
	}

	log.Println("Database seeding completed successfully!")
	fmt.Println("\nSeeded users:")
	for i, u := range users {
		if i < len(createdUsers) {
			fmt.Printf("  - %s (ID: %d, password: %s)\n", u.username, createdUsers[i], u.password)
		}
	}
}

