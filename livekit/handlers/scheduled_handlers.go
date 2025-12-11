package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"livekit/auth"
	"livekit/database"
	"livekit/services"
	"net/http"
	"strconv"
	"time"
)

func HandleCreateScheduledCall(db *database.DB, scheduledService *services.ScheduledService) http.HandlerFunc {
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

		var req services.CreateScheduledCallRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			log.Printf("Error decoding scheduled call request: %v", err)
			auth.RespondError(w, http.StatusBadRequest, fmt.Sprintf("Invalid request body: %v", err))
			return
		}

		if req.CallType != "video" && req.CallType != "voice" {
			auth.RespondError(w, http.StatusBadRequest, "callType must be 'video' or 'voice'")
			return
		}

		if req.ScheduledAt.Before(time.Now()) {
			auth.RespondError(w, http.StatusBadRequest, "scheduledAt must be in the future")
			return
		}

		call, err := scheduledService.CreateScheduledCall(userInfo.UserID, req)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		auth.RespondJSON(w, http.StatusCreated, call)
	}
}

func HandleGetScheduledCalls(db *database.DB, scheduledService *services.ScheduledService) http.HandlerFunc {
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

		status := r.URL.Query().Get("status")
		calls, err := scheduledService.GetScheduledCalls(userInfo.UserID, status)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		auth.RespondJSON(w, http.StatusOK, calls)
	}
}

func HandleGetScheduledCallDetails(db *database.DB, scheduledService *services.ScheduledService) http.HandlerFunc {
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

		idStr := r.URL.Query().Get("id")
		if idStr == "" {
			auth.RespondError(w, http.StatusBadRequest, "id is required")
			return
		}

		id, err := strconv.ParseInt(idStr, 10, 64)
		if err != nil {
			auth.RespondError(w, http.StatusBadRequest, "invalid id")
			return
		}

		call, err := scheduledService.GetScheduledCall(id)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		if call == nil {
			auth.RespondError(w, http.StatusNotFound, "Scheduled call not found")
			return
		}

		if call.CreatedBy != userInfo.UserID {
			auth.RespondError(w, http.StatusForbidden, "Access denied")
			return
		}

		auth.RespondJSON(w, http.StatusOK, call)
	}
}

func HandleUpdateScheduledCall(db *database.DB, scheduledService *services.ScheduledService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut {
			auth.RespondError(w, http.StatusMethodNotAllowed, "Method not allowed")
			return
		}

		userInfo, ok := auth.GetUserFromContext(r.Context())
		if !ok {
			auth.RespondError(w, http.StatusUnauthorized, "Not authenticated")
			return
		}

		idStr := r.URL.Query().Get("id")
		if idStr == "" {
			auth.RespondError(w, http.StatusBadRequest, "id is required")
			return
		}

		id, err := strconv.ParseInt(idStr, 10, 64)
		if err != nil {
			auth.RespondError(w, http.StatusBadRequest, "invalid id")
			return
		}

		call, err := scheduledService.GetScheduledCall(id)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if call == nil {
			auth.RespondError(w, http.StatusNotFound, "Scheduled call not found")
			return
		}
		if call.CreatedBy != userInfo.UserID {
			auth.RespondError(w, http.StatusForbidden, "Access denied")
			return
		}

		var updates map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
			auth.RespondError(w, http.StatusBadRequest, "Invalid request body")
			return
		}

		if err := scheduledService.UpdateScheduledCall(id, updates); err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		auth.RespondJSON(w, http.StatusOK, map[string]string{"message": "Scheduled call updated"})
	}
}

func HandleCancelScheduledCall(db *database.DB, scheduledService *services.ScheduledService) http.HandlerFunc {
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

		idStr := r.URL.Query().Get("id")
		if idStr == "" {
			auth.RespondError(w, http.StatusBadRequest, "id is required")
			return
		}

		id, err := strconv.ParseInt(idStr, 10, 64)
		if err != nil {
			auth.RespondError(w, http.StatusBadRequest, "invalid id")
			return
		}

		if err := scheduledService.CancelScheduledCall(id, userInfo.UserID); err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		auth.RespondJSON(w, http.StatusOK, map[string]string{"message": "Scheduled call cancelled"})
	}
}

func HandleStartScheduledCall(db *database.DB, scheduledService *services.ScheduledService) http.HandlerFunc {
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

		idStr := r.URL.Query().Get("id")
		if idStr == "" {
			auth.RespondError(w, http.StatusBadRequest, "id is required")
			return
		}

		id, err := strconv.ParseInt(idStr, 10, 64)
		if err != nil {
			auth.RespondError(w, http.StatusBadRequest, "invalid id")
			return
		}

		call, err := scheduledService.GetScheduledCall(id)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if call == nil {
			auth.RespondError(w, http.StatusNotFound, "Scheduled call not found")
			return
		}

		// Check authorization: user must be creator or invitee
		if call.CreatedBy != userInfo.UserID {
			isInvitee, err := scheduledService.IsInvitee(id, userInfo.UserID)
			if err != nil {
				log.Printf("Error checking invitee status: %v", err)
				auth.RespondError(w, http.StatusInternalServerError, "Failed to verify authorization")
				return
			}
			if !isInvitee {
				auth.RespondError(w, http.StatusForbidden, "Access denied: user is not creator or invitee")
				return
			}
		}

		result, err := scheduledService.StartScheduledCall(id, userInfo.UserID)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		auth.RespondJSON(w, http.StatusOK, result)
	}
}
