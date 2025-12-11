package handlers

import (
	"livekit/auth"
	"livekit/database"
	"livekit/models"
	"livekit/services"
	"log"
	"net/http"
	"strconv"
	"time"
)

func HandleGetCallHistory(db *database.DB, historyService *services.HistoryService) http.HandlerFunc {
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

		limit := 50
		if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
			if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
				limit = l
			}
		}

		offset := 0
		if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
			if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
				offset = o
			}
		}

		startDateStr := r.URL.Query().Get("startDate")
		endDateStr := r.URL.Query().Get("endDate")

		var histories []*models.CallHistory
		var err error

		if startDateStr != "" && endDateStr != "" {
			startDate, err1 := time.Parse(time.RFC3339, startDateStr)
			endDate, err2 := time.Parse(time.RFC3339, endDateStr)
			if err1 == nil && err2 == nil {
				histories, err = historyService.GetCallHistoryByDateRange(userInfo.UserID, startDate, endDate)
			} else {
				histories, err = historyService.GetCallHistory(userInfo.UserID, limit, offset)
			}
		} else {
			histories, err = historyService.GetCallHistory(userInfo.UserID, limit, offset)
		}

		if err != nil {
			log.Printf("Error getting call history for user %d: %v", userInfo.UserID, err)
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		auth.RespondJSON(w, http.StatusOK, histories)
	}
}

func HandleGetCallDetails(db *database.DB, historyService *services.HistoryService) http.HandlerFunc {
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

		callID := r.URL.Query().Get("callId")
		if callID == "" {
			auth.RespondError(w, http.StatusBadRequest, "callId is required")
			return
		}

		history, err := historyService.GetCallDetails(callID)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		if history == nil {
			auth.RespondError(w, http.StatusNotFound, "Call history not found")
			return
		}

		if history.CreatedBy != userInfo.UserID {
			auth.RespondError(w, http.StatusForbidden, "Access denied")
			return
		}

		auth.RespondJSON(w, http.StatusOK, history)
	}
}

func HandleDeleteCallHistory(db *database.DB, historyService *services.HistoryService) http.HandlerFunc {
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

		callID := r.URL.Query().Get("callId")
		if callID == "" {
			auth.RespondError(w, http.StatusBadRequest, "callId is required")
			return
		}

		history, err := historyService.GetCallDetails(callID)
		if err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		if history == nil {
			auth.RespondError(w, http.StatusNotFound, "Call history not found")
			return
		}

		if history.CreatedBy != userInfo.UserID {
			auth.RespondError(w, http.StatusForbidden, "Access denied")
			return
		}

		if err := historyService.DeleteCallHistory(callID); err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		auth.RespondJSON(w, http.StatusOK, map[string]string{"message": "Call history deleted"})
	}
}
