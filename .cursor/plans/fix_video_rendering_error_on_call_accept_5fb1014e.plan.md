---
name: Fix video rendering error on call accept
overview: Fix the RTCVideoRenderer error when accepting incoming video calls by adding proper video track readiness checks and loading placeholders in ParticipantTile, and ensuring smooth navigation to call screen.
todos: []
---

# Fix Video Rendering Error on Call Accept

## Problem

When accepting an incoming video call, the app navigates to `CallScreen` immediately after connecting to LiveKit, but video tracks may not be ready yet. This causes an error: "Can't set srcObject: The RTCVideoRenderer is disposed" or "Call initialize before setting the stream" from `rtc_video_renderer_impl.dart`.

## Solution

1. **Add video track readiness checks in `ParticipantTile`**: Check if video tracks are subscribed and ready before rendering
2. **Show loading placeholder**: Display avatar/placeholder while video tracks are initializing
3. **Improve call screen loading state**: Ensure `CallScreen` handles the initial loading phase gracefully

## Implementation

### 1. Update `lib/widgets/participant_tile.dart`

- Add method to check if video track is ready for rendering (check if track exists, is subscribed, and not disposed)
- Show placeholder (avatar with loading indicator) when video track is not ready
- Only render `VideoTrackRenderer` when track is confirmed ready
- Add state management to handle track readiness changes

### 2. Update `lib/screens/call_screen.dart`

- Ensure loading state is properly handled when participants list is empty or tracks are not ready
- The existing `CircularProgressIndicator` for empty participants should cover initial loading

### 3. Update `lib/screens/incoming_call_screen.dart` (if needed)

- Current flow navigates after `liveKitService.connect()` completes, which is correct
- No changes needed here, but ensure error handling is robust

## Technical Details

The key issue is that `VideoTrackRenderer` tries to render a track before it's fully initialized. We need to:

- Check `videoPub?.subscribed == true` (for remote participants)
- Check if track is not null and not disposed
- Use a stateful approach or stream listener to react to track readiness changes
- Show a placeholder UI (avatar + name) while waiting

## Files to Modify

- `lib/widgets/participant_tile.dart` - Add video readiness checks and placeholder
- `lib/screens/call_screen.dart` - Verify loading states (may not need changes)