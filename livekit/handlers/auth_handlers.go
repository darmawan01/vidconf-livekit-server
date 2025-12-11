package handlers

import (
	"encoding/json"
	"livekit/auth"
	"livekit/database"
	"net/http"
)

type RegisterRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type AuthResponse struct {
	Token    string      `json:"token"`
	User     interface{} `json:"user"`
}

func HandleRegister(db *database.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			auth.RespondError(w, http.StatusMethodNotAllowed, "Method not allowed")
			return
		}

		var req RegisterRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			auth.RespondError(w, http.StatusBadRequest, "Invalid request body")
			return
		}

		if req.Username == "" || req.Password == "" {
			auth.RespondError(w, http.StatusBadRequest, "Username and password are required")
			return
		}

		if len(req.Password) < 6 {
			auth.RespondError(w, http.StatusBadRequest, "Password must be at least 6 characters")
			return
		}

		userRepo := database.NewUserRepo(db)
		exists, err := userRepo.Exists(req.Username)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to check username")
			return
		}
		if exists {
			auth.RespondError(w, http.StatusConflict, "Username already exists")
			return
		}

		passwordHash, err := auth.HashPassword(req.Password)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to hash password")
			return
		}

		user, err := userRepo.Create(req.Username, passwordHash)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to create user")
			return
		}

		token, err := auth.GenerateToken(user.ID, user.Username)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to generate token")
			return
		}

		auth.RespondJSON(w, http.StatusCreated, AuthResponse{
			Token: token,
			User:  user,
		})
	}
}

func HandleLogin(db *database.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			auth.RespondError(w, http.StatusMethodNotAllowed, "Method not allowed")
			return
		}

		var req LoginRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			auth.RespondError(w, http.StatusBadRequest, "Invalid request body")
			return
		}

		if req.Username == "" || req.Password == "" {
			auth.RespondError(w, http.StatusBadRequest, "Username and password are required")
			return
		}

		userRepo := database.NewUserRepo(db)
		user, err := userRepo.GetByUsername(req.Username)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to get user")
			return
		}
		if user == nil {
			auth.RespondError(w, http.StatusUnauthorized, "Invalid credentials")
			return
		}

		if err := auth.VerifyPassword(user.PasswordHash, req.Password); err != nil {
			auth.RespondError(w, http.StatusUnauthorized, "Invalid credentials")
			return
		}

		token, err := auth.GenerateToken(user.ID, user.Username)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to generate token")
			return
		}

		auth.RespondJSON(w, http.StatusOK, AuthResponse{
			Token: token,
			User: map[string]interface{}{
				"id":        user.ID,
				"username":  user.Username,
				"createdAt": user.CreatedAt,
			},
		})
	}
}

func HandleMe(db *database.DB) http.HandlerFunc {
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

		userRepo := database.NewUserRepo(db)
		user, err := userRepo.GetByID(userInfo.UserID)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to get user")
			return
		}
		if user == nil {
			auth.RespondError(w, http.StatusNotFound, "User not found")
			return
		}

		auth.RespondJSON(w, http.StatusOK, user)
	}
}


