# LiveKit Token Server

HTTP server for generating LiveKit access tokens and automatically creating rooms.

## Configuration

Set the following environment variables:

- `LIVEKIT_API_KEY` (required) - Your LiveKit API key
- `LIVEKIT_API_SECRET` (required) - Your LiveKit API secret
- `LIVEKIT_HOST` (optional) - LiveKit server URL (default: `http://localhost:7880`)
- `SERVER_PORT` (optional) - Port for this server (default: `8080`)
- `ROOM_EMPTY_TIMEOUT` (optional) - Room empty timeout in seconds (default: `600`)
- `ROOM_MAX_PARTICIPANTS` (optional) - Maximum participants per room (default: `20`)

## Running the Server

```bash
export LIVEKIT_API_KEY="your_api_key"
export LIVEKIT_API_SECRET="your_api_secret"
export LIVEKIT_HOST="http://your-livekit-server:7880"
export SERVER_PORT=8080

go run .
```

Or build and run:

```bash
go build -o livekit-server .
./livekit-server
```

## API Endpoints

### POST /api/token

Generate a token for joining a LiveKit room. Automatically creates the room if it doesn't exist.

**Request:**
```json
{
  "roomName": "my-room",
  "username": "john-doe"
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "roomName": "my-room"
}
```

**Error Response:**
```json
{
  "error": "roomName is required"
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "ok"
}
```

## CORS

The server includes CORS middleware allowing requests from any origin. Adjust the CORS settings in `handlers.go` if needed for production.
