package livekit

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
)

type TokenRequest struct {
	RoomName string `json:"roomName"`
	Username string `json:"username"`
}

type TokenResponse struct {
	Token    string `json:"token"`
	RoomName string `json:"roomName"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

type HealthResponse struct {
	Status string `json:"status"`
}

func CorsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func HandleHealth(cfg *Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		response := HealthResponse{Status: "ok"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}
}

func HandleToken(cfg *Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req TokenRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			log.Printf("Error decoding request: %v", err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(ErrorResponse{Error: "Invalid request body"})
			return
		}

		if req.RoomName == "" {
			log.Printf("Missing roomName in request")
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(ErrorResponse{Error: "roomName is required"})
			return
		}

		if req.Username == "" {
			log.Printf("Missing username in request")
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(ErrorResponse{Error: "username is required"})
			return
		}

		if err := createRoom(cfg, req.RoomName); err != nil {
			log.Printf("Warning: Failed to create room '%s': %v", req.RoomName, err)
		}

		token, err := getJoinToken(cfg, req.RoomName, req.Username)
		if err != nil {
			log.Printf("Error generating token: %v", err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(ErrorResponse{Error: "Failed to generate token"})
			return
		}

		log.Printf("Token generated for room '%s' and user '%s'", req.RoomName, req.Username)

		response := TokenResponse{
			Token:    token,
			RoomName: req.RoomName,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}
}

func createRoom(cfg *Config, roomName string) error {
	at := auth.NewAccessToken(cfg.APIKey, cfg.APISecret)
	grant := &auth.VideoGrant{
		RoomCreate: true,
	}
	at.SetVideoGrant(grant).
		SetIdentity("room-creator").
		SetValidFor(5 * time.Minute)

	token, err := at.ToJWT()
	if err != nil {
		return fmt.Errorf("failed to create token: %w", err)
	}

	reqBody := livekit.CreateRoomRequest{
		Name:            roomName,
		EmptyTimeout:    uint32(cfg.EmptyTimeout),
		MaxParticipants: uint32(cfg.MaxParticipants),
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/twirp/livekit.RoomService/CreateRoom", cfg.LiveKitHost)
	req, err := http.NewRequestWithContext(context.Background(), "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		if resp.StatusCode == http.StatusConflict {
			log.Printf("Room '%s' already exists", roomName)
			return nil
		}
		return fmt.Errorf("failed to create room: status %d, body: %s", resp.StatusCode, string(body))
	}

	log.Printf("Room '%s' created successfully", roomName)
	return nil
}

func getJoinToken(cfg *Config, room, identity string) (string, error) {
	at := auth.NewAccessToken(cfg.APIKey, cfg.APISecret)
	grant := &auth.VideoGrant{
		RoomJoin:   true,
		RoomCreate: true,
		Room:       room,
	}
	at.SetVideoGrant(grant).
		SetIdentity(identity).
		SetValidFor(24 * time.Hour)

	token, err := at.ToJWT()
	if err != nil {
		return "", fmt.Errorf("failed to generate token: %w", err)
	}
	return token, nil
}
