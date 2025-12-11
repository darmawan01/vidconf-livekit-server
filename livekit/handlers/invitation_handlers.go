package handlers

import (
	"encoding/json"
	"livekit/auth"
	"livekit/database"
	"livekit/services"
	"net/http"
	"strconv"
)

type CallServiceConfig struct {
	APIKey          string
	APISecret       string
	LiveKitHost     string
	EmptyTimeout    int
	MaxParticipants int
}

type InviteRequest struct {
	CallType string   `json:"callType"`
	Invitees []string `json:"invitees"`
	RoomName string   `json:"roomName,omitempty"`
}

type RespondInvitationRequest struct {
	Action string `json:"action"`
}

func HandleInvite(db *database.DB, callService *services.CallService) http.HandlerFunc {
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

		var req InviteRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			auth.RespondError(w, http.StatusBadRequest, "Invalid request body")
			return
		}

		if req.CallType != "video" && req.CallType != "voice" {
			auth.RespondError(w, http.StatusBadRequest, "callType must be 'video' or 'voice'")
			return
		}

		if len(req.Invitees) == 0 {
			auth.RespondError(w, http.StatusBadRequest, "At least one invitee is required")
			return
		}

		result, err := callService.CreateCallAndInvite(userInfo.UserID, req.CallType, req.Invitees, req.RoomName)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		auth.RespondJSON(w, http.StatusCreated, result)
	}
}

func HandleGetInvitations(db *database.DB) http.HandlerFunc {
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

		invitationRepo := database.NewInvitationRepo(db)
		invitations, err := invitationRepo.GetPendingForUser(userInfo.UserID)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, "Failed to get invitations")
			return
		}

		auth.RespondJSON(w, http.StatusOK, invitations)
	}
}

func HandleRespondInvitation(db *database.DB, callService *services.CallService) http.HandlerFunc {
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

		invitationIDStr := r.URL.Query().Get("invitationId")
		if invitationIDStr == "" {
			auth.RespondError(w, http.StatusBadRequest, "invitationId query parameter is required")
			return
		}

		invitationID, err := strconv.ParseInt(invitationIDStr, 10, 64)
		if err != nil {
			auth.RespondError(w, http.StatusBadRequest, "Invalid invitation ID")
			return
		}

		var req RespondInvitationRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			auth.RespondError(w, http.StatusBadRequest, "Invalid request body")
			return
		}

		if req.Action != "accept" && req.Action != "reject" {
			auth.RespondError(w, http.StatusBadRequest, "action must be 'accept' or 'reject'")
			return
		}

		result, err := callService.RespondToInvitation(invitationID, userInfo.UserID, req.Action)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		if result == nil {
			auth.RespondJSON(w, http.StatusOK, map[string]string{"message": "Invitation rejected"})
			return
		}

		auth.RespondJSON(w, http.StatusOK, result)
	}
}

