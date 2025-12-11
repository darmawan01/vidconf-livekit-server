---
name: Backend Token Server and Modern UI
overview: Transform the video conferencing app with a proper backend token server (auto-create rooms) and a modern, Google Meet/WhatsApp-inspired mobile UI with video/voice call type selection.
todos:
  - id: backend-http-server
    content: Convert main.go to HTTP server with net/http, add CORS middleware, and basic routing
    status: pending
  - id: backend-env-config
    content: Move hardcoded credentials to environment variables (API_KEY, API_SECRET, HOST, PORT)
    status: pending
  - id: backend-token-endpoint
    content: Create POST /api/token endpoint that accepts roomName and username, auto-creates room, and returns token
    status: pending
  - id: backend-room-creation
    content: Uncomment and improve createRoom() function with proper error handling for existing rooms
    status: pending
  - id: backend-health-endpoint
    content: Add GET /health endpoint for server health checks
    status: pending
  - id: frontend-api-service
    content: Create lib/services/api_service.dart to fetch tokens from backend /api/token endpoint
    status: pending
  - id: frontend-app-config
    content: Create lib/config/app_config.dart for centralized server URL configuration
    status: pending
  - id: frontend-home-redesign
    content: Redesign home_screen.dart with modern UI (gradient, card layout), remove server/token inputs, add call type selection (video/voice)
    status: pending
  - id: frontend-call-screen-redesign
    content: Redesign video_call_screen.dart with Google Meet-inspired layout (adaptive grid), WhatsApp-style controls, and call type adaptation (video grid vs voice avatars)
    status: pending
  - id: frontend-livekit-enhancements
    content: Enhance livekit_service.dart to support CallType enum and conditionally enable camera based on call type
    status: pending
  - id: frontend-participant-avatar
    content: Create lib/widgets/participant_avatar.dart for voice call mode with colored circles, initials, and audio indicators
    status: pending
  - id: frontend-ui-components
    content: "Create reusable UI widgets: modern_button.dart, call_control_button.dart, participant_tile.dart"
    status: pending
  - id: frontend-visual-polish
    content: Add app theme, animations, loading states, error handling, and responsive design optimizations
    status: pending
---

# Backend Token Server and Modern UI Implementation Plan

## Overview

This plan separates the work into two parallel tracks: **Backend Server** (Go) and **Client App** (Flutter). The backend will handle token generation and automatic room creation, while the client will feature a modern UI with call type selection.

---

## Part 1: Backend Server (`livekit/main.go`)

### Current State

- Hardcoded credentials in constants
- No HTTP server - just a main function
- Room creation logic exists but commented out
- Token generation function exists

### Implementation Tasks

#### 1.1 Convert to HTTP Server

- Replace `main()` function with HTTP server setup
- Use Go's standard `net/http` package
- Add CORS middleware for Flutter app access
- Configure server to read from environment variables or config file

#### 1.2 Environment Configuration

- Move hardcoded values to environment variables:
  - `LIVEKIT_API_KEY`
  - `LIVEKIT_API_SECRET`
  - `LIVEKIT_HOST` (default: `http://localhost:7880`)
  - `SERVER_PORT` (default: `8080`)
- Add `.env` file support or use `os.Getenv()`
- Create example `.env.example` file

#### 1.3 Token Endpoint (`POST /api/token`)

- Accept JSON request: `{ "roomName": string, "username": string }`
- Validate input (non-empty room name and username)
- Call `createRoom()` to ensure room exists (handle 409 conflict gracefully)
- Generate join token using `getJoinToken()`
- Return JSON response: `{ "token": string, "roomName": string }`
- Handle errors with appropriate HTTP status codes

#### 1.4 Room Creation Logic

- Uncomment and improve `createRoom()` function
- Ensure it handles existing rooms gracefully (409 status)
- Add proper error handling and logging
- Configure room settings (empty_timeout, max_participants) from env or defaults

#### 1.5 Health Check Endpoint (`GET /health`)

- Simple endpoint to verify server is running
- Return `{ "status": "ok" }`

#### 1.6 Error Handling & Logging

- Add structured logging
- Proper error responses with JSON format
- Log room creation attempts and token generation

---

## Part 2: Client App (Flutter)

### Current State

- Basic home screen with manual token input
- Simple video call screen with grid layout
- Hardcoded server address and token
- No call type selection
- Basic UI without modern styling

### Implementation Tasks

#### 2.1 API Service Layer

- Create `lib/services/api_service.dart`
- Add method `Future<String> getToken(String roomName, String username, String serverUrl)`
- Make HTTP POST request to backend `/api/token` endpoint
- Handle errors and network failures gracefully
- Remove hardcoded token logic from `home_screen.dart`

#### 2.2 App Configuration

- Create `lib/config/app_config.dart`
- Store backend server URL (default: `http://localhost:8080`)
- Store LiveKit WebSocket URL (default: `ws://localhost:7880`)
- Allow configuration via environment or constants
- Remove hardcoded server addresses

#### 2.3 Enhanced Home Screen (`lib/screens/home_screen.dart`)

- **Modern UI Design:**
  - Gradient background (purple/blue like Google Meet)
  - Centered card with rounded corners and shadow
  - Large app icon/logo at top
  - Clean input fields with modern styling
  - Remove server address input (use config)
  - Remove static token toggle (use backend)

- **Call Type Selection:**
  - Add segmented control or toggle buttons for "Video Call" / "Voice Call"
  - Store selected call type in state
  - Visual indicators (icons) for each call type

- **Input Fields:**
  - Room name input with validation
  - Username input with validation
  - Modern Material 3 styling

- **Join Button:**
  - Large, prominent button with gradient
  - Loading state with spinner
  - Disabled state when inputs invalid

#### 2.4 Enhanced Video Call Screen (`lib/screens/video_call_screen.dart`)

- **Modern Layout (Google Meet inspired):**
  - Full-screen video grid with adaptive layout
  - 1 participant: full screen
  - 2 participants: side-by-side split
  - 3-4 participants: 2x2 grid
  - 5+ participants: scrollable grid with pagination

- **Call Type Adaptation:**
  - **Video Call Mode:**
    - Show video tracks prominently
    - Grid layout with video feeds
    - Participant avatars when video off

  - **Voice Call Mode (WhatsApp style):**
    - Large circular avatars with initials/colors
    - Participant names displayed prominently
    - No video grid (or minimized)
    - Focus on audio indicators

- **Modern Controls Bar:**
  - Floating bottom bar with glassmorphism effect
  - Large circular buttons (like WhatsApp)
  - Color coding: green (active), red (muted/disabled)
  - Smooth animations and transitions
  - Button states: mic, camera, end call, switch camera (video only)

- **Top Bar:**
  - Room name and participant count
  - Call duration timer
  - Minimize/expand controls
  - Connection status indicator

#### 2.5 LiveKit Service Enhancements (`lib/services/livekit_service.dart`)

- Add `CallType` enum: `video` and `voice`
- Modify `connect()` to accept `CallType` parameter
- Conditionally enable camera based on call type:
  - Video call: enable camera
  - Voice call: disable camera (audio only)
- Add method to toggle call type during call (optional future enhancement)
- Fix bug in `toggleAudio()` - missing `enabled` variable declaration

#### 2.6 Participant Avatar Widget

- Create `lib/widgets/participant_avatar.dart`
- Generate colored circles with initials
- Show participant name
- Audio indicator (pulsing when speaking)
- Video off indicator overlay

#### 2.7 UI Components

- Create `lib/widgets/modern_button.dart` - reusable styled buttons
- Create `lib/widgets/call_control_button.dart` - specialized call controls
- Create `lib/widgets/participant_tile.dart` - unified participant display
- Add animations using Flutter animations package

#### 2.8 Responsive Design

- Optimize for mobile (primary target)
- Handle different screen sizes
- Portrait and landscape orientations
- Safe area handling for notches

#### 2.9 Visual Polish

- Add app theme with custom colors
- Smooth transitions between screens
- Loading states and skeletons
- Error states with retry options
- Success animations

---

## File Structure Changes

### Backend

```
livekit/
├── main.go (HTTP server with endpoints)
├── handlers.go (HTTP handlers)
├── config.go (configuration management)
├── .env.example (example environment variables)
└── go.mod (existing)
```

### Frontend

```
lib/
├── config/
│   └── app_config.dart
├── services/
│   ├── livekit_service.dart (enhanced)
│   └── api_service.dart (new)
├── screens/
│   ├── home_screen.dart (redesigned)
│   └── video_call_screen.dart (redesigned)
└── widgets/
    ├── participant_avatar.dart (new)
    ├── modern_button.dart (new)
    ├── call_control_button.dart (new)
    └── participant_tile.dart (new)
```

---

## Dependencies

### Backend

- Existing: `github.com/livekit/protocol`
- Add: Standard library only (no new deps needed)

### Frontend

- Existing: `livekit_client`, `provider`, `http`, `crypto`
- Consider adding: `flutter_animate` or `animations` package for smooth transitions

---

## Testing Considerations

### Backend

- Test token endpoint with valid/invalid inputs
- Test room creation (new and existing)
- Test error handling
- Test CORS headers

### Frontend

- Test token fetching from backend
- Test video and voice call modes
- Test UI responsiveness
- Test error states and retry logic

---

## Implementation Order

1. **Backend First** (can work in parallel with frontend prep):

   - Set up HTTP server structure
   - Implement token endpoint
   - Test with curl/Postman

2. **Frontend Integration**:

   - Create API service
   - Update home screen to use backend
   - Test end-to-end flow

3. **UI Enhancement** (can work in parallel):

   - Redesign home screen
   - Redesign call screen
   - Add call type selection
   - Polish and animations

---

## Notes

- Backend and frontend can be developed in parallel after initial API contract is defined
- Keep backward compatibility during transition if needed
- Use environment variables for all sensitive/configurable values
- Follow Flutter and Go best practices for code organization