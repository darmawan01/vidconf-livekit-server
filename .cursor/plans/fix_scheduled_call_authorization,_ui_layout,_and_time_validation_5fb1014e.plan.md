---
name: Fix scheduled call authorization, UI layout, and time validation
overview: "Fix 5 production issues: 1) Allow invitees to join scheduled calls (403 fix), 2) Fix UI layout overflow for long DateTime text, 3) Hide cancel button for non-creators, 4) Add duration validation for join, 5) Hide join button and prevent access when meeting is out of range."
todos:
  - id: backend-invitee-auth
    content: Add IsInvitee method and update HandleStartScheduledCall to allow invitees to join
    status: completed
  - id: backend-time-validation
    content: Add time range validation in StartScheduledCall (check scheduledAt + duration)
    status: completed
  - id: frontend-ui-overflow
    content: Fix UI layout overflow for long DateTime text in scheduled call cards
    status: completed
  - id: frontend-hide-cancel
    content: Hide cancel button for non-creators in scheduled call cards
    status: completed
  - id: frontend-time-validation
    content: Add client-side time validation and hide join button when meeting is out of range
    status: completed
---

# Fix Scheduled Call Authorization, UI Layout, and Time Validation

## Issues Identified

1. **403 Not Allowed for Participants**: `HandleStartScheduledCall` only allows the creator to start/join, but invitees should also be able to join
2. **UI Layout Overflow**: Long DateTime text overlaps with join/cancel buttons on scheduled call cards
3. **Cancel Button Access**: Participants can see and use cancel button, but only creator should be able to cancel
4. **Duration Validation Missing**: No check if current time is within scheduled time + duration window
5. **Out of Range Access**: Join button should be hidden and access prevented when scheduled time + duration has passed

## Implementation Plan

### 1. Fix 403 Authorization for Invitees

**File**: `livekit/handlers/scheduled_handlers.go`

- **Current**: Line 246 checks `if call.CreatedBy != userID` and returns 403
- **Fix**: Check if user is creator OR invitee (via `scheduled_call_invitations` table)
- **Implementation**: 
- Add helper method in `ScheduledService` to check if user is invitee: `IsInvitee(scheduledCallID, userID)`
- Update `HandleStartScheduledCall` to allow if `call.CreatedBy == userID || isInvitee`

**File**: `livekit/services/scheduled_service.go`

- Add `IsInvitee(scheduledCallID int64, userID int64) (bool, error)` method
- Update `StartScheduledCall` to accept `userID` parameter and validate authorization
- Add time range validation: check if current time is within `scheduledAt` to `scheduledAt + maxDurationSeconds`

### 2. Fix UI Layout Overflow

**File**: `lib/screens/scheduled_calls_screen.dart`

- **Issue**: `Row` with DateTime text can overflow when text is long
- **Fix**: 
- Wrap DateTime `Text` widget with `Expanded` or `Flexible` to allow wrapping
- Add `overflow: TextOverflow.ellipsis` and `maxLines: 1` to DateTime text
- Ensure proper spacing between subtitle content and trailing buttons
- Consider using `Expanded` for subtitle content area

### 3. Hide Cancel Button for Non-Creators

**File**: `lib/screens/scheduled_calls_screen.dart`

- **Current**: Cancel button shown for all users when `isUpcoming && status == scheduled`
- **Fix**: 
- Get current user ID/username from `AuthService`
- Compare with `call.createdBy` (need to add this field to model or get from API)
- Only show cancel button if user is the creator
- Alternative: Check if user is creator by comparing username with creator username from invitees list

**File**: `lib/models/scheduled_call.dart`

- Ensure `createdBy` field is available (check if it's already there)
- Or add method to get creator username

**File**: `livekit/services/scheduled_service.go`

- Ensure `GetScheduledCalls` returns creator information (username or userID)

### 4. Add Duration Validation for Join

**File**: `livekit/services/scheduled_service.go`

- **In `StartScheduledCall` method**:
- Calculate end time: `endTime := call.ScheduledAt.Add(time.Duration(call.MaxDurationSeconds) * time.Second)`
- Check if `time.Now().Before(endTime)` - if false, return error "Meeting has ended"
- Also check if `time.Now().Before(call.ScheduledAt)` - if true, optionally allow early join or return error

**File**: `lib/screens/scheduled_calls_screen.dart`

- **In `_joinCall` method**:
- Add client-side validation before calling API
- Calculate `endTime = call.scheduledAt.add(Duration(seconds: call.maxDurationSeconds))`
- Check if `DateTime.now().isAfter(endTime)` - if true, show error and don't call API
- Check if meeting hasn't started yet (optional - may want to allow early join)

### 5. Hide Join Button and Prevent Access When Out of Range

**File**: `lib/screens/scheduled_calls_screen.dart`

- **In build method, for each call card**:
- Calculate `endTime = call.scheduledAt.add(Duration(seconds: call.maxDurationSeconds))`
- Check if `DateTime.now().isAfter(endTime)` - if true, don't show join button
- Also check if call status is not "scheduled" - don't show join button
- Update `isUpcoming` logic to also consider duration

**File**: `livekit/services/scheduled_service.go`

- **In `StartScheduledCall`**:
- Add server-side validation to prevent access when out of range
- Return appropriate error message

## Implementation Order

1. Backend: Add `IsInvitee` method and update authorization in `HandleStartScheduledCall`
2. Backend: Add time range validation in `StartScheduledCall`
3. Frontend: Fix UI layout overflow (wrap text, add ellipsis)
4. Frontend: Hide cancel button for non-creators
5. Frontend: Add client-side time validation and hide join button when out of range
6. Testing: Verify all scenarios work correctly

## Additional Production Readiness

- Add proper error messages for all validation failures
- Ensure consistent timezone handling (use UTC consistently)
- Add logging for authorization failures
- Consider adding rate limiting for join attempts

### 6. Fix Call Screen UI Overlap and Multi-Participant Support

**File**: `lib/screens/call_screen.dart`

- **Issue 1**: Bottom controls bar overlaps with local video in bottom right corner
- **Issue 2**: Current layout only supports 2 participants (1 remote + 1 local)
- **Fix**:
- Adjust local video position to avoid overlap with controls bar (move higher or adjust padding)
- Implement flexible grid layout for multiple participants:
- For 2 participants: Current layout (full-screen remote + small local)
- For 3-4 participants: 2x2 grid layout
- For 5+ participants: Scrollable grid (3 columns, multiple rows)
- Use `GridView` or custom layout based on participant count
- Ensure local participant is always visible (pinned or in grid)
- Adjust controls bar padding/position to not overlap with any video tiles

**File**: `lib/services/livekit_service.dart`

- Verify `remoteParticipants` list properly tracks all remote participants
- Ensure participant add/remove events are properly handled

**File**: `lib/widgets/participant_tile.dart`

- Ensure it works correctly in grid layout (proper sizing, aspect ratio)