# Local Notifications Implementation

## Overview

The local notifications system for Duet triggers notifications when idea processing completes, but only when the user is not actively using the app. This provides a non-intrusive way to inform users about completed processing.

## Features

✅ **Smart App State Detection** - Only sends notifications when app is backgrounded/closed  
✅ **Proper Permission Handling** - Requests permissions on app launch gracefully  
✅ **Deep Linking** - Notifications open directly to the completed idea detail view  
✅ **Group Support** - Handles both personal and group ideas  
✅ **Automatic Cleanup** - Clears notifications when user returns to app  
✅ **Testing Support** - Includes test notification methods for development  

## Implementation

### Core Components

1. **NotificationManager.swift** - Main notification handling class
2. **DuetApp.swift** - App-level setup and deep link handling
3. **ProcessingManager.swift** - Integration with idea processing completion

### Key Features

#### Permission Management
- Requests notification permissions on app launch
- Tracks permission state with `@Published` properties
- Graceful handling of denied permissions

#### App State Detection
- Uses `UIApplication.applicationState` and scene activation states
- Only sends notifications when app is not active
- Monitors scene phase changes to clear notifications when app becomes active

#### Deep Linking
- Notifications contain idea ID and optional group ID
- Tapping notification opens `DateIdeaDetailView` with the completed idea
- Uses `NotificationCenter` for internal deep link communication

## Testing Instructions

### 1. Test Permission Request
1. Delete and reinstall the app (to reset permissions)
2. Launch the app - you should see a permission dialog
3. Grant permission when prompted

### 2. Test Notification Delivery
You can test notifications in several ways:

#### Method A: Process a Real Video (Recommended)
1. Background/close the app
2. Use the share extension to process a video URL
3. Wait for processing to complete (you'll receive a notification)
4. Tap the notification to verify deep linking works

#### Method B: Use Test Notifications (For Development)
Add this code temporarily in your app to test:

```swift
// Add this to a button in your UI for testing
Button("Test Notification") {
    notificationManager.scheduleTestNotification()
}

// Or force a notification regardless of app state
Button("Force Test Notification") {
    notificationManager.forceScheduleTestNotification()
}
```

### 3. Test Deep Linking
1. Ensure you have at least one completed idea
2. Background the app and wait for a notification
3. Tap the notification
4. Verify it opens the correct idea detail view

### 4. Test App State Detection
1. Keep the app open and process a video
2. You should NOT receive a notification (since app is active)
3. Background the app and process another video
4. You SHOULD receive a notification

## Integration Points

### ProcessingManager Integration
The notification is triggered in `ProcessingManager.handleCompletedJob()`:

```swift
// Send local notification if app is not active
notificationManager.scheduleIdeaCompletedNotification(
    ideaId: result.id,
    ideaTitle: result.summary.title,
    groupId: job.groupId
)
```

### App Lifecycle Integration
- Permissions requested on app launch
- Notifications cleared when app becomes active
- Deep links handled through `NotificationCenter`

## Configuration

### Notification Content
- **Title**: Idea title (e.g., "Romantic Picnic in Central Park")
- **Body**: "Your idea has finished processing, tap to view."
- **Sound**: Default system sound
- **Badge**: Cleared when app becomes active

### Identifiers
- Format: `"idea_completed_\{ideaId}"`
- Allows for individual notification cancellation
- Prevents duplicate notifications for same idea

## Best Practices

1. **Test on Physical Device** - Simulator has notification limitations
2. **Test Permission States** - Verify behavior when permissions are denied
3. **Test Background Processing** - Ensure notifications work with share extension
4. **Verify Deep Linking** - Test that tapped notifications open correct screens
5. **Check App State Logic** - Verify no notifications when app is active

## Troubleshooting

### No Notifications Appearing
1. Check notification permissions in Settings > Duet > Notifications
2. Verify app is actually backgrounded (not just minimized)
3. Check console logs for notification scheduling messages
4. Try `forceScheduleTestNotification()` for debugging

### Deep Linking Not Working
1. Verify `NotificationCenter` observer is set up correctly
2. Check that `DateIdeaDetailView` navigation is working
3. Ensure network requests for idea details are succeeding

### Notifications Appearing When App is Active
1. Check `isAppActive()` logic in `NotificationManager`
2. Verify scene phase detection is working correctly
3. Test with different app states (active, inactive, background)

## Console Output

The system provides detailed logging:

```
📱 Notification Status:
   - Permission: true
   - App Active: false
   - Authorization: 2

✅ Scheduled notification for idea: Romantic Picnic in Central Park
📱 App became active - cleared notifications
```

## Future Enhancements

- [ ] Notification categories for different actions
- [ ] Rich notifications with idea thumbnails
- [ ] Batch notifications for multiple completed ideas
- [ ] Custom notification sounds
- [ ] Notification scheduling optimization 