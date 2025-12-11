package websocket

import (
	"encoding/json"
	"livekit/models"
	"log"
	"sync"
	"time"
)

type WebSocketHub struct {
	connections map[string]*Connection
	mu          sync.RWMutex
}

type Connection struct {
	Username string
	Send     chan []byte
}

type Message struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

type InvitationMessage struct {
	InvitationID int64  `json:"invitationId"`
	CallID        string `json:"callId"`
	Inviter       string `json:"inviter"`
	CallType      string `json:"callType"`
	RoomName      string `json:"roomName"`
	Timestamp     string `json:"timestamp"`
}

type InvitationResponseMessage struct {
	InvitationID int64  `json:"invitationId"`
	Invitee       string `json:"invitee"`
	Status        string `json:"status"`
	Timestamp     string `json:"timestamp"`
}

func NewWebSocketHub() *WebSocketHub {
	return &WebSocketHub{
		connections: make(map[string]*Connection),
	}
}

func (h *WebSocketHub) Register(username string, conn *Connection) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.connections[username] = conn
	log.Printf("User %s connected to WebSocket", username)
}

func (h *WebSocketHub) Unregister(username string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if conn, ok := h.connections[username]; ok {
		close(conn.Send)
		delete(h.connections, username)
		log.Printf("User %s disconnected from WebSocket", username)
	}
}

func (h *WebSocketHub) BroadcastInvitation(username string, invitation *models.Invitation) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	log.Printf("Broadcasting invitation to user: %s, invitation ID: %d, inviter: %s", username, invitation.ID, invitation.Inviter)
	log.Printf("Connected users: %v", h.getConnectedUsernames())

	conn, ok := h.connections[username]
	if !ok {
		log.Printf("User %s not connected, cannot send invitation. Available connections: %v", username, h.getConnectedUsernames())
		return
	}

	msg := Message{
		Type: "call_invitation",
		Data: InvitationMessage{
			InvitationID: invitation.ID,
			CallID:        invitation.CallID,
			Inviter:       invitation.Inviter,
			CallType:      invitation.CallType,
			RoomName:      invitation.RoomName,
			Timestamp:     invitation.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		},
	}

	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal invitation message: %v", err)
		return
	}

	select {
	case conn.Send <- data:
		log.Printf("Successfully sent invitation to %s", username)
	default:
		log.Printf("Failed to send invitation to %s: channel full", username)
	}
}

func (h *WebSocketHub) getConnectedUsernames() []string {
	usernames := make([]string, 0, len(h.connections))
	for username := range h.connections {
		usernames = append(usernames, username)
	}
	return usernames
}

func (h *WebSocketHub) BroadcastInvitationResponse(username string, invitationID int64, invitee string, status string) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	conn, ok := h.connections[username]
	if !ok {
		return
	}

	msgType := "invitation_rejected"
	if status == "accepted" {
		msgType = "invitation_accepted"
	}

	msg := Message{
		Type: msgType,
		Data: InvitationResponseMessage{
			InvitationID: invitationID,
			Invitee:       invitee,
			Status:        status,
			Timestamp:     "",
		},
	}

	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal invitation response message: %v", err)
		return
	}

	select {
	case conn.Send <- data:
	default:
		log.Printf("Failed to send invitation response to %s: channel full", username)
	}
}

func (h *WebSocketHub) BroadcastCallEnded(username string, callID string) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	conn, ok := h.connections[username]
	if !ok {
		return
	}

	msg := Message{
		Type: "call_ended",
		Data: map[string]interface{}{
			"callId":    callID,
			"timestamp": "",
		},
	}

	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal call ended message: %v", err)
		return
	}

	select {
	case conn.Send <- data:
	default:
		log.Printf("Failed to send call ended to %s: channel full", username)
	}
}

func (h *WebSocketHub) BroadcastCallCancelled(username string, callID string) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	conn, ok := h.connections[username]
	if !ok {
		return
	}

	msg := Message{
		Type: "call_cancelled",
		Data: map[string]interface{}{
			"callId":    callID,
			"timestamp": "",
		},
	}

	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal call cancelled message: %v", err)
		return
	}

	select {
	case conn.Send <- data:
	default:
		log.Printf("Failed to send call cancelled to %s: channel full", username)
	}
}

func (h *WebSocketHub) BroadcastScheduledCallCreated(username string, call *models.ScheduledCall) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	conn, ok := h.connections[username]
	if !ok {
		return
	}

	msg := Message{
		Type: "scheduled_call_created",
		Data: call,
	}

	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal scheduled call created message: %v", err)
		return
	}

	select {
	case conn.Send <- data:
	default:
		log.Printf("Failed to send scheduled call created to %s: channel full", username)
	}
}

func (h *WebSocketHub) BroadcastScheduledCallReminder(username string, call *models.ScheduledCall, reminderTime time.Duration) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	conn, ok := h.connections[username]
	if !ok {
		return
	}

	msg := Message{
		Type: "scheduled_call_reminder",
		Data: map[string]interface{}{
			"scheduledCall": call,
			"reminderTime":   reminderTime.String(),
		},
	}

	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal scheduled call reminder message: %v", err)
		return
	}

	select {
	case conn.Send <- data:
	default:
		log.Printf("Failed to send scheduled call reminder to %s: channel full", username)
	}
}

func (h *WebSocketHub) BroadcastScheduledCallStarting(username string, call *models.ScheduledCall) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	conn, ok := h.connections[username]
	if !ok {
		return
	}

	msg := Message{
		Type: "scheduled_call_starting",
		Data: call,
	}

	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal scheduled call starting message: %v", err)
		return
	}

	select {
	case conn.Send <- data:
	default:
		log.Printf("Failed to send scheduled call starting to %s: channel full", username)
	}
}

func (h *WebSocketHub) BroadcastCallHistoryUpdated(username string, callHistory *models.CallHistory) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	conn, ok := h.connections[username]
	if !ok {
		return
	}

	msg := Message{
		Type: "call_history_updated",
		Data: callHistory,
	}

	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal call history updated message: %v", err)
		return
	}

	select {
	case conn.Send <- data:
	default:
		log.Printf("Failed to send call history updated to %s: channel full", username)
	}
}

func (h *WebSocketHub) BroadcastParticipantStateChanged(username string, roomName string, participantIdentity string, action string) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	conn, ok := h.connections[username]
	if !ok {
		return
	}

	msg := Message{
		Type: "participant_state_changed",
		Data: map[string]interface{}{
			"roomName":           roomName,
			"participantIdentity": participantIdentity,
			"action":             action,
		},
	}

	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal participant state changed message: %v", err)
		return
	}

	select {
	case conn.Send <- data:
	default:
		log.Printf("Failed to send participant state changed to %s: channel full", username)
	}
}


