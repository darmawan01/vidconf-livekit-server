package handlers

import (
	"livekit/auth"
	"livekit/database"
	"livekit/services"
	"net/http"
)

func HandleEndCall(db *database.DB, callService *services.CallService) http.HandlerFunc {
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

		callID := r.URL.Query().Get("callId")
		if callID == "" {
			auth.RespondError(w, http.StatusBadRequest, "callId is required")
			return
		}

		if err := callService.EndCall(callID, userInfo.UserID); err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		auth.RespondJSON(w, http.StatusOK, map[string]string{"message": "Call ended"})
	}
}

func HandleCancelCall(db *database.DB, callService *services.CallService) http.HandlerFunc {
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

		callID := r.URL.Query().Get("callId")
		if callID == "" {
			auth.RespondError(w, http.StatusBadRequest, "callId is required")
			return
		}

		if err := callService.CancelCall(callID, userInfo.UserID); err != nil {
			auth.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		auth.RespondJSON(w, http.StatusOK, map[string]string{"message": "Call cancelled"})
	}
}

