package main

import (
	"context"
	"fmt"
	"livekit"
	"livekit/auth"
	"livekit/database"
	"livekit/handlers"
	"livekit/services"
	"livekit/websocket"
	"livekit/workers"
	"log"
	"net/http"
)

type CreateRoomRequest struct {
	Name            string `json:"name"`
	EmptyTimeout    int    `json:"empty_timeout,omitempty"`
	MaxParticipants int    `json:"max_participants,omitempty"`
}

func main() {
	cfg, err := livekit.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	db, err := database.NewDB()
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()
	log.Println("Database initialized successfully")

	wsHub := websocket.NewWebSocketHub()

	callServiceConfig := &services.CallServiceConfig{
		APIKey:          cfg.APIKey,
		APISecret:       cfg.APISecret,
		LiveKitHost:     cfg.LiveKitHost,
		EmptyTimeout:    cfg.EmptyTimeout,
		MaxParticipants: cfg.MaxParticipants,
	}

	callService, err := services.NewCallService(db, callServiceConfig, wsHub)
	if err != nil {
		log.Fatalf("Failed to initialize call service: %v", err)
	}

	historyService := services.NewHistoryService(db)
	scheduledService := services.NewScheduledService(db, callService, wsHub)

	ctx := context.Background()
	scheduledWorker := workers.NewScheduledWorker(scheduledService, db, wsHub)
	go scheduledWorker.Run(ctx)

	mux := http.NewServeMux()

	cors := livekit.CorsMiddleware

	mux.Handle("/api/auth/register", cors(handlers.HandleRegister(db)))
	mux.Handle("/api/auth/login", cors(handlers.HandleLogin(db)))
	mux.Handle("/api/auth/me", cors(auth.AuthMiddleware(handlers.HandleMe(db))))

	mux.Handle("/api/contacts/add", cors(auth.AuthMiddleware(handlers.HandleAddContact(db))))
	mux.Handle("/api/contacts", cors(auth.AuthMiddleware(handlers.HandleGetContacts(db))))
	mux.Handle("/api/contacts/remove", cors(auth.AuthMiddleware(handlers.HandleRemoveContact(db))))
	mux.Handle("/api/contacts/search", cors(auth.AuthMiddleware(handlers.HandleSearchContacts(db))))

	mux.Handle("/api/calls/invite", cors(auth.AuthMiddleware(handlers.HandleInvite(db, callService))))
	mux.Handle("/api/calls/invitations", cors(auth.AuthMiddleware(handlers.HandleGetInvitations(db))))
	mux.Handle("/api/calls/invitations/respond", cors(auth.AuthMiddleware(handlers.HandleRespondInvitation(db, callService))))
	mux.Handle("/api/calls/end", cors(auth.AuthMiddleware(handlers.HandleEndCall(db, callService))))
	mux.Handle("/api/calls/cancel", cors(auth.AuthMiddleware(handlers.HandleCancelCall(db, callService))))

	mux.Handle("/api/calls/history", cors(auth.AuthMiddleware(handlers.HandleGetCallHistory(db, historyService))))
	mux.Handle("/api/calls/history/details", cors(auth.AuthMiddleware(handlers.HandleGetCallDetails(db, historyService))))
	mux.Handle("/api/calls/history/delete", cors(auth.AuthMiddleware(handlers.HandleDeleteCallHistory(db, historyService))))

	mux.Handle("/api/calls/scheduled", cors(auth.AuthMiddleware(handlers.HandleCreateScheduledCall(db, scheduledService))))
	mux.Handle("/api/calls/scheduled/list", cors(auth.AuthMiddleware(handlers.HandleGetScheduledCalls(db, scheduledService))))
	mux.Handle("/api/calls/scheduled/details", cors(auth.AuthMiddleware(handlers.HandleGetScheduledCallDetails(db, scheduledService))))
	mux.Handle("/api/calls/scheduled/update", cors(auth.AuthMiddleware(handlers.HandleUpdateScheduledCall(db, scheduledService))))
	mux.Handle("/api/calls/scheduled/cancel", cors(auth.AuthMiddleware(handlers.HandleCancelScheduledCall(db, scheduledService))))
	mux.Handle("/api/calls/scheduled/start", cors(auth.AuthMiddleware(handlers.HandleStartScheduledCall(db, scheduledService))))

	mux.Handle("/ws", cors(websocket.HandleWebSocket(wsHub)))

	mux.Handle("/api/token", cors(livekit.HandleToken(cfg)))
	mux.Handle("/health", cors(livekit.HandleHealth(cfg)))

	serverAddr := fmt.Sprintf(":%d", cfg.ServerPort)
	log.Printf("Starting server on %s", serverAddr)
	log.Printf("LiveKit host: %s", cfg.LiveKitHost)
	log.Printf("Health endpoint: http://localhost%s/health", serverAddr)

	if err := http.ListenAndServe(serverAddr, mux); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
