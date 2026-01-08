# LiveKit Video Conference - Complete Call Flow Documentation

## Overview

This document describes the end-to-end call flow in the LiveKit video conference system, from call initiation to successful connection between users. The system consists of:

- **Backend**: Golang server handling authentication, call management, and signaling
- **LiveKit Server**: Media relay and WebRTC infrastructure
- **Client**: Browser/mobile application using LiveKit SDK

---

## Architecture Overview

```mermaid
graph TB
    subgraph "Client Application"
        UI[UI/UX Layer]
        Auth[Auth Module]
        WS[WebSocket Client]
        LK[LiveKit SDK Client]
    end

    subgraph "Backend Server (Golang)"
        API[HTTP API Handlers]
        CallSvc[Call Service]
        WSHub[WebSocket Hub]
        HistSvc[History Service]
        PartSvc[Participant Service]
        DB[(SQLite Database)]
    end

    subgraph "LiveKit Server"
        RoomMgr[Room Manager]
        TokenVal[Token Validator]
        MediaRelay[Media Relay]
    end

    UI --> API
    Auth --> API
    WS --> WSHub
    LK --> MediaRelay

    API --> CallSvc
    CallSvc --> WSHub
    CallSvc --> HistSvc
    CallSvc --> PartSvc
    CallSvc --> DB
    CallSvc --> RoomMgr

    RoomMgr --> TokenVal
    TokenVal --> MediaRelay
```

---

## Complete E2E Call Flow Sequence

```mermaid
sequenceDiagram
    participant AliceUI as Alice (Client)
    participant Backend as Go Backend
    participant WSHub as WebSocket Hub
    participant LKServer as LiveKit Server
    participant BobWS as Bob (WebSocket)
    participant BobUI as Bob (Client)

    Note over AliceUI,BobUI: Phase 1: Authentication
    AliceUI->>Backend: POST /api/auth/login
    Backend->>Backend: Verify credentials
    Backend-->>AliceUI: JWT Token

    BobUI->>Backend: POST /api/auth/login
    Backend->>Backend: Verify credentials
    Backend-->>BobUI: JWT Token

    Note over AliceUI,BobUI: Phase 2: WebSocket Connection
    AliceUI->>WSHub: WS /ws
    AliceUI->>WSHub: {type: "authenticate", token: JWT}
    WSHub->>WSHub: Validate JWT
    WSHub-->>AliceUI: {type: "authenticated"}

    BobUI->>WSHub: WS /ws
    BobUI->>WSHub: {type: "authenticate", token: JWT}
    WSHub->>WSHub: Validate JWT
    WSHub-->>BobUI: {type: "authenticated"}

    Note over AliceUI,BobUI: Phase 3: Call Initiation
    AliceUI->>Backend: POST /api/calls/invite<br/>{invitees: ["bob"], callType: "video"}
    Backend->>Backend: Generate callID, roomName
    Backend->>LKServer: CreateRoom(roomName)
    LKServer-->>Backend: Room created
    Backend->>Backend: Insert active_calls, call_invitations, call_history
    Backend->>Backend: Generate LiveKit token for Alice
    Backend->>WSHub: BroadcastInvitation(bob)
    Backend-->>AliceUI: {callId, roomName, token}
    WSHub-->>BobWS: {type: "call_invitation", data: {...}}

    Note over AliceUI,BobUI: Phase 4: Alice Joins Room
    AliceUI->>LKServer: Connect to room<br/>(token, roomName, identity: alice)
    LKServer->>LKServer: Validate token
    LKServer-->>AliceUI: WebRTC connection established
    AliceUI->>LKServer: Publish video/audio tracks

    Note over AliceUI,BobUI: Phase 5: Bob Accepts Call
    BobUI->>BobUI: User clicks Accept
    BobUI->>Backend: POST /api/calls/invitations/respond<br/>{action: "accept"}
    Backend->>Backend: Update invitation status to 'accepted'
    Backend->>Backend: Generate LiveKit token for Bob
    Backend->>WSHub: Notify Alice (accepted)
    Backend-->>BobUI: {token, roomName}
    WSHub-->>AliceUI: {type: "invitation_accepted"}

    Note over AliceUI,BobUI: Phase 6: Bob Joins Room
    BobUI->>LKServer: Connect to room<br/>(token, roomName, identity: bob)
    LKServer->>LKServer: Validate token
    LKServer-->>BobUI: WebRTC connection established
    BobUI->>LKServer: Publish video/audio tracks
    LKServer-->>AliceUI: participant_joined event
    LKServer-->>BobUI: participant_joined event

    Note over AliceUI,BobUI: Phase 7: Active Call
    AliceUI<<->>LKServer: Media stream (video/audio)
    LKServer<<->>BobUI: Media stream (video/audio)

    Note over AliceUI,BobUI: Phase 8: Call End
    AliceUI->>AliceUI: User clicks End Call
    AliceUI->>Backend: POST /api/calls/end?callId=...
    Backend->>LKServer: ListParticipants(roomName)
    LKServer-->>Backend: Participant list
    Backend->>Backend: Update call_history (status=completed, duration)
    Backend->>Backend: Update active_calls (status=ended)
    Backend->>WSHub: Broadcast call_ended
    Backend-->>AliceUI: Call ended
    WSHub-->>BobUI: {type: "call_ended"}
    AliceUI->>LKServer: Disconnect
    BobUI->>LKServer: Disconnect
    LKServer->>LKServer: Room cleanup (after emptyTimeout)
```

---

## Detailed Flow by Phase

### Phase 1: User Authentication

```mermaid
flowchart TD
    Start([Client starts app]) --> Login["POST /api/auth/login"]
    Login --> ValidateCreds{Valid credentials?}
    ValidateCreds -->|No| LoginError[Return 401 Unauthorized]
    ValidateCreds -->|Yes| GenerateJWT["Generate JWT Token<br/>userId, username, exp: 24h"]
    GenerateJWT --> ReturnToken["Return token + user info"]
    ReturnToken --> StoreToken[Client stores JWT]
    StoreToken --> Ready([Ready for calls])
```

**Key Components:**
- Handler: `HandleLogin` in `livekit/handlers/auth_handlers.go`
- Service: Password verification using bcrypt
- Database: Query `users` table
- Token: HS256 signed JWT with 24-hour expiry

---

### Phase 2: Call Initiation (Caller Side)

```mermaid
flowchart TD
    Start([User initiates call]) --> CallAPI["POST /api/calls/invite<br/>Authorization: Bearer JWT"]
    CallAPI --> AuthMiddleware{Valid JWT?}
    AuthMiddleware -->|No| AuthError[Return 401]
    AuthMiddleware -->|Yes| GenIDs["Generate callID & roomName UUIDs"]
    GenIDs --> CreateRoom["CallService.createRoom<br/>LiveKit API: CreateRoom"]
    CreateRoom --> RoomSuccess{Room created?}
    RoomSuccess -->|No| RoomError[Return 500]
    RoomSuccess -->|Yes| InsertDB["Insert records:<br/>1. active_calls<br/>2. call_invitations<br/>3. call_history"]
    InsertDB --> GenToken["Generate LiveKit token<br/>Identity: caller username<br/>Room: roomName<br/>Permissions: RoomJoin, RoomCreate"]
    GenToken --> Broadcast["WebSocketHub.BroadcastInvitation<br/>for each invitee"]
    Broadcast --> Return["Return callId, roomName, token"]
    Return --> End([Client connects to LiveKit])
```

**Database Operations:**

```sql
-- 1. Create active call
INSERT INTO active_calls (call_id, room_name, call_type, created_by, status, created_at)
VALUES ('uuid1', 'uuid2', 'video', 123, 'active', NOW());

-- 2. Create invitation for each invitee
INSERT INTO call_invitations (call_id, inviter_id, invitee_id, call_type, room_name, status, created_at)
VALUES ('uuid1', 123, 456, 'video', 'uuid2', 'pending', NOW());

-- 3. Create history record
INSERT INTO call_history (call_id, room_name, call_type, created_by, participants, started_at, status)
VALUES ('uuid1', 'uuid2', 'video', 123, '["alice", "bob"]', NOW(), 'pending');
```

**LiveKit Token Claims:**

```json
{
  "video": {
    "roomJoin": true,
    "roomCreate": true,
    "room": "uuid2",
    "canPublish": true,
    "canPublishData": true
  },
  "identity": "alice",
  "exp": 1640000000
}
```

---

### Phase 3: Invitation Reception (Callee Side)

```mermaid
flowchart TD
    Start([Backend creates invitation]) --> CheckWS{"User connected<br/>to WebSocket?"}
    CheckWS -->|No| StoreOnly["Store in DB only<br/>Notification sent when user connects"]
    CheckWS -->|Yes| LookupConn["WebSocketHub.BroadcastInvitation<br/>Find connection by username"]
    LookupConn --> BuildMsg["Construct message:<br/>type: call_invitation<br/>invitationId, callId, inviter, roomName"]
    BuildMsg --> SendWS[Send to WebSocket channel]
    SendWS --> ClientReceive[Client receives notification]
    ClientReceive --> ShowUI["Display incoming call UI<br/>Caller name, Call type, Accept/Reject"]
    StoreOnly --> WaitConnect([Wait for user to connect])
    ShowUI --> AwaitResponse([Await user action])
```

**WebSocket Message Format:**

```json
{
  "type": "call_invitation",
  "data": {
    "invitationId": 123,
    "callId": "uuid1",
    "inviter": "alice",
    "callType": "video",
    "roomName": "uuid2",
    "createdAt": "2026-01-08T12:00:00Z"
  }
}
```

---

### Phase 4: Invitation Response

```mermaid
flowchart TD
    Start([User clicks Accept/Reject]) --> SendResponse["POST /api/calls/invitations/respond?invitationId=123<br/>Body: action accept or reject"]
    SendResponse --> ValidateInv{"Invitation exists<br/>& belongs to user?"}
    ValidateInv -->|No| InvError[Return 404 or 403]
    ValidateInv -->|Yes| CheckAction{Action?}

    CheckAction -->|accept| UpdateAccept["Update invitation.status = accepted"]
    UpdateAccept --> GenBobToken["Generate LiveKit token<br/>Identity: bob<br/>Room: roomName<br/>Permissions: RoomJoin"]
    GenBobToken --> NotifyAlice["WebSocket: Notify Alice<br/>type: invitation_accepted"]
    NotifyAlice --> ReturnAccept["Return token and roomName"]
    ReturnAccept --> BobJoins([Bob connects to LiveKit])

    CheckAction -->|reject| UpdateReject["Update invitation.status = rejected<br/>Update history.status = rejected"]
    UpdateReject --> NotifyAliceReject["WebSocket: Notify Alice<br/>type: invitation_rejected"]
    NotifyAliceReject --> ReturnReject[Return empty response]
    ReturnReject --> CallCancelled([Call cancelled])
```

**Accept Response:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "roomName": "uuid2"
}
```

**WebSocket Notifications:**

```json
// To caller when accepted
{
  "type": "invitation_accepted",
  "data": {
    "callId": "uuid1",
    "invitee": "bob"
  }
}

// To caller when rejected
{
  "type": "invitation_rejected",
  "data": {
    "callId": "uuid1",
    "invitee": "bob"
  }
}
```

---

### Phase 5: LiveKit Connection

```mermaid
flowchart TD
    Start(["Client has token & roomName"]) --> Import[Import LiveKit SDK]
    Import --> CreateRoom["const room = new Room"]
    CreateRoom --> Connect["room.connect<br/>liveKitHost, token, options"]
    Connect --> ValidateToken{LiveKit validates token}
    ValidateToken -->|Invalid| ConnError[Connection error]
    ValidateToken -->|Valid| Establish["Establish WebRTC connection<br/>STUN/TURN negotiation"]
    Establish --> SetupTracks["Setup local tracks<br/>Camera, Microphone"]
    SetupTracks --> PublishTracks[Publish tracks to room]
    PublishTracks --> Subscribe[Subscribe to remote tracks]
    Subscribe --> EventHandlers["Register event handlers:<br/>participant_joined<br/>participant_left<br/>track_subscribed<br/>connection_quality_changed"]
    EventHandlers --> Connected(["User connected & visible in room"])

    Connected --> OtherJoins{"Other participant<br/>joins?"}
    OtherJoins -->|Yes| FireEvent[Fire participant_joined event]
    FireEvent --> RenderRemote[Render remote video/audio]
    RenderRemote --> ActiveCall([Active call with media exchange])
```

**Client-Side Code (Pseudo):**

```javascript
import { Room } from 'livekit-client';

// After receiving token and roomName from backend
const room = new Room({
  adaptiveStream: true,
  dynacast: true
});

// Event handlers
room.on('participant_joined', (participant) => {
  console.log('Participant joined:', participant.identity);
  renderParticipant(participant);
});

room.on('track_subscribed', (track, publication, participant) => {
  if (track.kind === 'video') {
    attachVideoTrack(track, participant);
  } else if (track.kind === 'audio') {
    attachAudioTrack(track, participant);
  }
});

// Connect to room
await room.connect(liveKitHost, token, {
  name: roomName,
  identity: username
});

// Publish local tracks
await room.localParticipant.enableCameraAndMicrophone();
```

**LiveKit Protocol Flow:**

```mermaid
sequenceDiagram
    participant Client
    participant LKSignal as LiveKit Signal Server
    participant LKMedia as LiveKit Media Server

    Client->>LKSignal: Connect WebSocket (wss://...)
    Client->>LKSignal: Join request (token, room)
    LKSignal->>LKSignal: Validate JWT token
    LKSignal-->>Client: Join response (participant info)

    Client->>LKSignal: Offer SDP (video/audio capabilities)
    LKSignal-->>Client: Answer SDP

    Client->>LKMedia: DTLS handshake
    Client->>LKMedia: SRTP keys exchange
    LKMedia-->>Client: Connection established

    Client->>LKMedia: RTP packets (video/audio)
    LKMedia-->>Client: RTP packets (from other participants)

    Note over Client,LKMedia: Active media streaming
```

---

### Phase 6: Active Call State

```mermaid
stateDiagram-v2
    [*] --> WaitingForInvitee: Call initiated
    WaitingForInvitee --> CallerAlone: Caller in room
    CallerAlone --> BothConnected: Invitee joins
    BothConnected --> MediaExchange: Tracks published
    MediaExchange --> MediaExchange: Active call
    MediaExchange --> Ending: End call requested
    Ending --> UpdatingDB: Update call_history
    UpdatingDB --> Notifying: Broadcast call_ended
    Notifying --> [*]: Call completed

    WaitingForInvitee --> Cancelled: Invitee rejects
    CallerAlone --> Cancelled: Caller cancels
    Cancelled --> [*]: Call cancelled
```

**State Tracking:**

| State | active_calls.status | call_invitations.status | call_history.status |
|-------|---------------------|-------------------------|---------------------|
| Created | active | pending | pending |
| Accepted | active | accepted | pending |
| Rejected | active | rejected | rejected |
| In Progress | active | accepted | pending |
| Ended | ended | accepted | completed |
| Cancelled | cancelled | cancelled | cancelled |

---

### Phase 7: Call Termination

```mermaid
flowchart TD
    Start([User clicks End Call]) --> ClientDisconnect["Client: room.disconnect"]
    ClientDisconnect --> CallAPI["POST /api/calls/end?callId=uuid1"]
    CallAPI --> GetCall[Fetch active_calls record]
    GetCall --> CallExists{Call exists?}
    CallExists -->|No| NotFoundError[Return 404]
    CallExists -->|Yes| GetParticipants["ListParticipants from LiveKit<br/>Get final participant list"]
    GetParticipants --> CalcDuration["Calculate duration<br/>ended_at - created_at"]
    CalcDuration --> UpdateHistory["Update call_history:<br/>status = completed<br/>ended_at = NOW<br/>duration_seconds"]
    UpdateHistory --> UpdateActive["Update active_calls:<br/>status = ended<br/>ended_at = NOW"]
    UpdateActive --> BroadcastEnd["WebSocket: Broadcast call_ended<br/>to all participants"]
    BroadcastEnd --> ReturnSuccess[Return success]
    ReturnSuccess --> ClientCleanup["Client cleans up UI<br/>Stops local tracks"]
    ClientCleanup --> RoomCleanup{Room empty?}
    RoomCleanup -->|Yes| EmptyTimeout[Wait emptyTimeout seconds]
    EmptyTimeout --> DestroyRoom[LiveKit destroys room]
    RoomCleanup -->|No| StayActive[Room stays active]
    DestroyRoom --> End([Call fully terminated])
```

**Database Updates:**

```sql
-- Update call history
UPDATE call_history
SET status = 'completed',
    ended_at = NOW(),
    duration_seconds = TIMESTAMPDIFF(SECOND, started_at, NOW())
WHERE call_id = 'uuid1';

-- Update active calls
UPDATE active_calls
SET status = 'ended',
    ended_at = NOW()
WHERE call_id = 'uuid1';
```

**WebSocket Notification:**

```json
{
  "type": "call_ended",
  "data": {
    "callId": "uuid1",
    "endedBy": "alice",
    "duration": 180
  }
}
```

---

## API Endpoints Reference

### Authentication

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| POST | `/api/auth/register` | Register new user | `{username, password}` | `{token, user}` |
| POST | `/api/auth/login` | Login user | `{username, password}` | `{token, user}` |
| GET | `/api/auth/me` | Get current user | - | `{user}` |

### Call Management

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| POST | `/api/calls/invite` | Initiate call | `{invitees: [usernames], callType}` | `{callId, roomName, token}` |
| GET | `/api/calls/invitations` | Get pending invitations | - | `[{invitation}]` |
| POST | `/api/calls/invitations/respond` | Accept/reject invitation | `{action: "accept" or "reject"}` | `{token, roomName}` |
| POST | `/api/calls/end` | End active call | `?callId=uuid` | `{success}` |
| POST | `/api/calls/cancel` | Cancel pending call | `?callId=uuid` | `{success}` |

### Token Generation

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| POST | `/api/token` | Generate LiveKit token | `{roomName, participantName}` | `{token}` |

### WebSocket

| Protocol | Endpoint | Description |
|----------|----------|-------------|
| WS | `/ws` | WebSocket connection for real-time notifications |

---

## WebSocket Message Types

### Client → Server

| Type | Description | Payload |
|------|-------------|---------|
| `authenticate` | Authenticate WebSocket connection | `{token: "JWT"}` |
| `ping` | Keep-alive ping | `{}` |

### Server → Client

| Type | Description | Payload |
|------|-------------|---------|
| `authenticated` | Authentication success | `{}` |
| `pong` | Keep-alive pong | `{}` |
| `call_invitation` | Incoming call notification | `{invitationId, callId, inviter, callType, roomName}` |
| `invitation_accepted` | Invitee accepted call | `{callId, invitee}` |
| `invitation_rejected` | Invitee rejected call | `{callId, invitee}` |
| `call_ended` | Call was ended | `{callId, endedBy, duration}` |
| `call_cancelled` | Call was cancelled | `{callId}` |

---

## Database Schema

```mermaid
erDiagram
    users ||--o{ active_calls : creates
    users ||--o{ call_invitations : invites
    users ||--o{ call_invitations : receives
    users ||--o{ call_history : creates
    active_calls ||--o{ call_invitations : has
    active_calls ||--|| call_history : tracks

    users {
        int id PK
        string username UK
        string password_hash
        datetime created_at
        datetime updated_at
    }

    active_calls {
        int id PK
        string call_id UK
        string room_name UK
        string call_type
        int created_by FK
        datetime created_at
        datetime ended_at
        string status
    }

    call_invitations {
        int id PK
        string call_id FK
        int inviter_id FK
        int invitee_id FK
        string call_type
        string room_name
        string status
        datetime created_at
        datetime responded_at
    }

    call_history {
        int id PK
        string call_id UK
        string room_name
        string call_type
        int created_by FK
        json participants
        datetime started_at
        datetime ended_at
        int duration_seconds
        string status
    }
```

---

## Configuration

### Environment Variables

```bash
# LiveKit Server Configuration
LIVEKIT_HOST=http://localhost:7880           # LiveKit server address
LIVEKIT_API_KEY=your-api-key                 # API key for LiveKit
LIVEKIT_API_SECRET=your-api-secret           # API secret for LiveKit

# Backend Server
SERVER_PORT=8080                              # Backend server port
JWT_SECRET=your-secret-key                    # JWT signing secret

# Database
DB_PATH=vidconf.db                            # SQLite database file path

# Room Configuration
ROOM_EMPTY_TIMEOUT=300                        # Seconds before destroying empty room
ROOM_MAX_PARTICIPANTS=20                      # Max participants per room
```

---

## Security Considerations

### JWT Tokens

1. **Backend JWT (HTTP API)**
   - Algorithm: HS256
   - Expiry: 24 hours
   - Claims: userId, username
   - Used for: HTTP request authentication

2. **LiveKit JWT (Media Connection)**
   - Algorithm: HS256 (signed with LIVEKIT_API_SECRET)
   - Expiry: 24 hours
   - Claims: video permissions, room name, identity
   - Used for: WebRTC connection authentication

### Authorization

- All HTTP endpoints (except `/auth/*` and `/health`) require valid JWT in `Authorization: Bearer` header
- WebSocket connections require authentication message with valid JWT
- LiveKit tokens are scoped to specific rooms and identities
- Room names are UUIDs to prevent enumeration attacks

### Data Validation

- Username uniqueness enforced at database level
- Invitation responses validated against invitee user ID
- Call end requests validated against active_calls records
- Password hashing using bcrypt with appropriate cost factor

---

## Error Handling

### Common HTTP Error Codes

| Code | Description | Scenarios |
|------|-------------|-----------|
| 400 | Bad Request | Invalid JSON, missing required fields |
| 401 | Unauthorized | Invalid/expired JWT, authentication failed |
| 403 | Forbidden | User not allowed to perform action |
| 404 | Not Found | Call/invitation/user not found |
| 409 | Conflict | Username already exists |
| 500 | Internal Server Error | Database errors, LiveKit connection failures |

### WebSocket Error Handling

- Connection failures: Auto-reconnect with exponential backoff (client-side)
- Invalid messages: Logged but connection not terminated
- Authentication failures: Connection closed with error message

---

## Performance Considerations

### Database

- Indexes on: `username`, `call_id`, `room_name`, `status` columns
- SQLite with WAL mode for concurrent reads
- Connection pooling for database access

### WebSocket

- Buffered channels (256 entries) for outbound messages
- Separate goroutines for read/write operations per connection
- Automatic cleanup of stale connections

### LiveKit

- Room reuse when possible (409 Conflict handling)
- Automatic room cleanup with `emptyTimeout`
- Token caching not implemented (tokens are short-lived)

---

## Example: Complete Call Flow Timeline

### Scenario: Alice calls Bob for a video chat

**T=0s: Alice initiates call**
```
POST /api/calls/invite
{
  "invitees": ["bob"],
  "callType": "video"
}

Backend:
1. Generates callID: "a1b2c3d4-..."
2. Generates roomName: "e5f6g7h8-..."
3. Creates LiveKit room "e5f6g7h8-..."
4. Inserts into active_calls, call_invitations, call_history
5. Generates token for Alice
6. Broadcasts invitation to Bob via WebSocket

Response to Alice:
{
  "callId": "a1b2c3d4-...",
  "roomName": "e5f6g7h8-...",
  "token": "eyJhbGci..."
}
```

**T=1s: Alice joins LiveKit room**
```javascript
await room.connect('http://localhost:7880', token, {
  name: 'e5f6g7h8-...',
  identity: 'alice'
});
await room.localParticipant.enableCameraAndMicrophone();
```

**T=2s: Bob receives WebSocket notification**
```json
{
  "type": "call_invitation",
  "data": {
    "invitationId": 123,
    "callId": "a1b2c3d4-...",
    "inviter": "alice",
    "callType": "video",
    "roomName": "e5f6g7h8-..."
  }
}
```

**T=5s: Bob accepts call**
```
POST /api/calls/invitations/respond?invitationId=123
{
  "action": "accept"
}

Backend:
1. Updates call_invitations.status = 'accepted'
2. Generates token for Bob
3. Sends WebSocket to Alice: {type: "invitation_accepted"}

Response to Bob:
{
  "token": "eyJhbGci...",
  "roomName": "e5f6g7h8-..."
}
```

**T=6s: Bob joins LiveKit room**
```javascript
await room.connect('http://localhost:7880', token, {
  name: 'e5f6g7h8-...',
  identity: 'bob'
});
await room.localParticipant.enableCameraAndMicrophone();
```

**T=6.5s: Both users see each other**
- Alice receives `participant_joined` event for Bob
- Bob receives `participant_joined` event for Alice
- Both render remote video/audio streams
- **Call is now active**

**T=180s: Alice ends call**
```
POST /api/calls/end?callId=a1b2c3d4-...

Backend:
1. Gets participants from LiveKit
2. Calculates duration: 180 seconds
3. Updates call_history: status='completed', duration=180
4. Updates active_calls: status='ended'
5. Broadcasts {type: "call_ended"} to Bob
```

**T=181s: Both disconnect**
- Alice and Bob close WebRTC connections
- LiveKit room becomes empty
- After 300s (emptyTimeout), LiveKit destroys room

---

## Monitoring & Debugging

### Useful Queries

```sql
-- Active calls
SELECT * FROM active_calls WHERE status = 'active';

-- Call history with participants
SELECT
  ch.call_id,
  ch.room_name,
  u.username as creator,
  ch.participants,
  ch.duration_seconds,
  ch.status
FROM call_history ch
JOIN users u ON ch.created_by = u.id
ORDER BY ch.started_at DESC;

-- Pending invitations
SELECT
  ci.id,
  u1.username as inviter,
  u2.username as invitee,
  ci.call_type,
  ci.created_at
FROM call_invitations ci
JOIN users u1 ON ci.inviter_id = u1.id
JOIN users u2 ON ci.invitee_id = u2.id
WHERE ci.status = 'pending';
```

### Health Check

```bash
curl http://localhost:8080/health
```

Response:
```json
{
  "status": "ok"
}
```

---

## Conclusion

This system provides a complete end-to-end video conferencing solution with:

- **Secure authentication** using JWT tokens
- **Real-time signaling** via WebSocket
- **Call management** with invitation flow
- **Media relay** through LiveKit infrastructure
- **Call history** and analytics
- **Scalable architecture** with clear separation of concerns

The flow ensures that all participants are properly authenticated, invited, and connected before media exchange begins, providing a robust and secure video conferencing experience.
