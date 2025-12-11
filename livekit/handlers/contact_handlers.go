package handlers

import (
	"encoding/json"
	"livekit/auth"
	"livekit/database"
	"net/http"
	"strconv"
)

type AddContactRequest struct {
	Username string `json:"username"`
}

func HandleAddContact(db *database.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			auth.RespondError(w, http.StatusMethodNotAllowed, "Method not allowed")
			return
		}

		userInfo, ok := auth.GetUserFromContext(r.Context())
		if !ok {
			auth.RespondError(w, http.StatusUnauthorized, "Not authenticated")
			return
		}

		var req AddContactRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			auth.RespondError(w, http.StatusBadRequest, "Invalid request body")
			return
		}

		if req.Username == "" {
			auth.RespondError(w, http.StatusBadRequest, "Username is required")
			return
		}

		if req.Username == userInfo.Username {
			auth.RespondError(w, http.StatusBadRequest, "Cannot add yourself as a contact")
			return
		}

		userRepo := database.NewUserRepo(db)
		contactUser, err := userRepo.GetByUsername(req.Username)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to find user")
			return
		}
		if contactUser == nil {
			auth.RespondError(w, http.StatusNotFound, "User not found")
			return
		}

		contactRepo := database.NewContactRepo(db)
		exists, err := contactRepo.Exists(userInfo.UserID, contactUser.ID)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to check contact")
			return
		}
		if exists {
			auth.RespondError(w, http.StatusConflict, "Contact already exists")
			return
		}

		if err := contactRepo.Add(userInfo.UserID, contactUser.ID); err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to add contact")
			return
		}

		auth.RespondJSON(w, http.StatusCreated, map[string]string{"message": "Contact added successfully"})
	}
}

func HandleGetContacts(db *database.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			auth.RespondError(w, http.StatusMethodNotAllowed, "Method not allowed")
			return
		}

		userInfo, ok := auth.GetUserFromContext(r.Context())
		if !ok {
			auth.RespondError(w, http.StatusUnauthorized, "Not authenticated")
			return
		}

		contactRepo := database.NewContactRepo(db)
		contacts, err := contactRepo.GetUserContacts(userInfo.UserID)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to get contacts")
			return
		}

		auth.RespondJSON(w, http.StatusOK, contacts)
	}
}

func HandleRemoveContact(db *database.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodDelete {
			auth.RespondError(w, http.StatusMethodNotAllowed, "Method not allowed")
			return
		}

		userInfo, ok := auth.GetUserFromContext(r.Context())
		if !ok {
			auth.RespondError(w, http.StatusUnauthorized, "Not authenticated")
			return
		}

		contactIDStr := r.URL.Query().Get("contactId")
		if contactIDStr == "" {
			auth.RespondError(w, http.StatusBadRequest, "contactId query parameter is required")
			return
		}

		contactID, err := strconv.ParseInt(contactIDStr, 10, 64)
		if err != nil {
			auth.RespondError(w, http.StatusBadRequest, "Invalid contact ID")
			return
		}

		contactRepo := database.NewContactRepo(db)
		if err := contactRepo.Remove(userInfo.UserID, contactID); err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to remove contact")
			return
		}

		auth.RespondJSON(w, http.StatusOK, map[string]string{"message": "Contact removed successfully"})
	}
}

func HandleSearchContacts(db *database.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			auth.RespondError(w, http.StatusMethodNotAllowed, "Method not allowed")
			return
		}

		userInfo, ok := auth.GetUserFromContext(r.Context())
		if !ok {
			auth.RespondError(w, http.StatusUnauthorized, "Not authenticated")
			return
		}

		query := r.URL.Query().Get("q")
		if query == "" {
			auth.RespondError(w, http.StatusBadRequest, "Query parameter 'q' is required")
			return
		}

		contactRepo := database.NewContactRepo(db)
		contacts, err := contactRepo.Search(userInfo.UserID, query)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to search contacts")
			return
		}

		auth.RespondJSON(w, http.StatusOK, contacts)
	}
}

