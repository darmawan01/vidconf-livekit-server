package livekit

import (
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	APIKey              string
	APISecret           string
	LiveKitHost         string
	ServerPort          int
	EmptyTimeout        int
	MaxParticipants     int
	MaxCallDuration     int
	DefaultCallDuration int
}

func LoadConfig() (*Config, error) {
	if err := godotenv.Load(); err != nil {
		log.Printf("Warning: Error loading .env file: %v (using environment variables only)", err)
	}

	apiKey := os.Getenv("LIVEKIT_API_KEY")
	if apiKey == "" {
		return nil, fmt.Errorf("LIVEKIT_API_KEY environment variable is required")
	}

	apiSecret := os.Getenv("LIVEKIT_API_SECRET")
	if apiSecret == "" {
		return nil, fmt.Errorf("LIVEKIT_API_SECRET environment variable is required")
	}

	liveKitHost := os.Getenv("LIVEKIT_HOST")
	if liveKitHost == "" {
		liveKitHost = "http://localhost:7880"
	}

	serverPort := 8080
	if portStr := os.Getenv("SERVER_PORT"); portStr != "" {
		port, err := strconv.Atoi(portStr)
		if err != nil {
			return nil, fmt.Errorf("invalid SERVER_PORT: %w", err)
		}
		serverPort = port
	}

	emptyTimeout := 0
	if timeoutStr := os.Getenv("ROOM_EMPTY_TIMEOUT"); timeoutStr != "" {
		timeout, err := strconv.Atoi(timeoutStr)
		if err == nil {
			emptyTimeout = timeout
		}
	}

	maxParticipants := 20
	if maxStr := os.Getenv("ROOM_MAX_PARTICIPANTS"); maxStr != "" {
		max, err := strconv.Atoi(maxStr)
		if err == nil {
			maxParticipants = max
		}
	}

	maxCallDuration := 0
	if durationStr := os.Getenv("MAX_CALL_DURATION"); durationStr != "" {
		duration, err := strconv.Atoi(durationStr)
		if err == nil {
			maxCallDuration = duration
		}
	}

	defaultCallDuration := 0
	if durationStr := os.Getenv("DEFAULT_CALL_DURATION"); durationStr != "" {
		duration, err := strconv.Atoi(durationStr)
		if err == nil {
			defaultCallDuration = duration
		}
	}

	return &Config{
		APIKey:              apiKey,
		APISecret:           apiSecret,
		LiveKitHost:         liveKitHost,
		ServerPort:          serverPort,
		EmptyTimeout:        emptyTimeout,
		MaxParticipants:     maxParticipants,
		MaxCallDuration:     maxCallDuration,
		DefaultCallDuration: defaultCallDuration,
	}, nil
}
