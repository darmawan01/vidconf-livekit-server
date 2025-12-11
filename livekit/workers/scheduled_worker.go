package workers

import (
	"context"
	"livekit/database"
	"livekit/services"
	"livekit/websocket"
	"log"
	"time"
)

type ScheduledWorker struct {
	scheduledService *services.ScheduledService
	userRepo         *database.UserRepo
	wsHub            *websocket.WebSocketHub
}

func NewScheduledWorker(scheduledService *services.ScheduledService, db *database.DB, wsHub *websocket.WebSocketHub) *ScheduledWorker {
	return &ScheduledWorker{
		scheduledService: scheduledService,
		userRepo:         database.NewUserRepo(db),
		wsHub:            wsHub,
	}
}

func (w *ScheduledWorker) Run(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// w.processScheduledCalls()
			w.sendReminders()
		}
	}
}

// func (w *ScheduledWorker) processScheduledCalls() {
// 	upcoming, err := w.scheduledService.GetUpcomingScheduledCalls(100)
// 	if err != nil {
// 		log.Printf("Error getting upcoming scheduled calls: %v", err)
// 		return
// 	}

// 	now := time.Now()
// 	for _, call := range upcoming {
// 		if call.ScheduledAt.Before(now) || call.ScheduledAt.Equal(now) {
// 			_, err := w.scheduledService.StartScheduledCall(call.ID, call.CreatedBy)
// 			if err != nil {
// 				log.Printf("Error starting scheduled call %d: %v", call.ID, err)
// 				continue
// 			}

// 			if w.wsHub != nil {
// 				username := w.getUsername(call.CreatedBy)
// 				if username != "" {
// 					w.wsHub.BroadcastScheduledCallStarting(username, call)
// 				}
// 			}

// 			log.Printf("Started scheduled call %s (ID: %d)", call.CallID, call.ID)
// 		}
// 	}
// }

func (w *ScheduledWorker) sendReminders() {
	upcoming, err := w.scheduledService.GetUpcomingScheduledCalls(100)
	if err != nil {
		log.Printf("Error getting upcoming scheduled calls for reminders: %v", err)
		return
	}

	now := time.Now()
	reminderTimes := []time.Duration{15 * time.Minute, 5 * time.Minute}

	for _, call := range upcoming {
		if call.ReminderSentAt != nil {
			continue
		}

		timeUntilCall := call.ScheduledAt.Sub(now)
		for _, reminderTime := range reminderTimes {
			if timeUntilCall <= reminderTime && timeUntilCall > reminderTime-time.Minute {
				if w.wsHub != nil {
					username := w.getUsername(call.CreatedBy)
					if username != "" {
						w.wsHub.BroadcastScheduledCallReminder(username, call, reminderTime)
					}
				}

				if err := w.scheduledService.UpdateReminderSent(call.ID); err != nil {
					log.Printf("Error updating reminder sent: %v", err)
				}

				break
			}
		}
	}
}

func (w *ScheduledWorker) getUsername(userID int64) string {
	user, err := w.userRepo.GetByID(userID)
	if err != nil || user == nil {
		log.Printf("Error getting user %d: %v", userID, err)
		return ""
	}
	return user.Username
}

func (w *ScheduledWorker) UpdateReminderSent(callID int64) error {
	return w.scheduledService.UpdateReminderSent(callID)
}
