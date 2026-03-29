# Announcement System

## Overview
The announcement system displays an admin-controlled message every time users launch the app. This is designed to be a major source of updates during events.

## How It Works

### User Experience
1. **Every app launch** shows the welcome dialog
2. Dialog displays:
   - Timestamp of when admin last updated the message
   - The current announcement message
3. User taps "I Understand" to dismiss
4. Next launch will show the same dialog with potentially updated info

### Technical Implementation

#### Files Created/Modified:
- `ManagersAnnouncementManager.swift` - New file managing announcements
- `ViewsRootView.swift` - Updated to use announcement system
- `ServicesMockDataService.swift` - Added announcement storage/retrieval

#### Data Flow:
1. `RootView` loads on app launch
2. `.task` modifier fetches latest announcement from `MockDataService`
3. `AnnouncementManager` updates `@Published` properties
4. Dialog displays the admin timestamp and message

### Mock Data
The default announcement is set to 2 hours ago in the past, so you can see how relative timestamps work.

## Testing the Feature

### Current Behavior:
When you launch the app, you'll see:
```
Mar 23, 2026 at [2 hours ago time]

Welcome to the Blue Lake Springs Event Tracker...
```

### To Test Admin Updates:
You can simulate an admin update by adding this code anywhere (like a button in your UI):

```swift
Button("Update Announcement (Admin)") {
    Task {
        try? await AnnouncementManager.shared.updateAnnouncement(
            message: "UPDATED: Power has been restored to Blue Lake Springs Dr. Side roads still affected."
        )
    }
}
```

After tapping this button, force close and relaunch the app. You'll see the new message with the current timestamp.

## Future Enhancements

### Settings Toggle (Planned)
You'll add a settings page where users can toggle:
```swift
@AppStorage("showAnnouncementOnLaunch") private var showAnnouncementOnLaunch = true
```

Then in `RootView`, wrap the dialog display:
```swift
.onAppear {
    if showAnnouncementOnLaunch {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showWelcome = true
        }
    }
}
```

### Admin Panel
When you build your admin interface, admins can update announcements via:
```swift
try await AnnouncementManager.shared.updateAnnouncement(
    message: "Your new announcement text here"
)
```

The timestamp is automatically set to the current time when the admin makes the update.

### Firebase Integration
When you're ready to move from mock data to real Firebase:
1. Create a `settings/announcement` document in Firestore
2. Update `AnnouncementManager` to use Firestore instead of `MockDataService`
3. Structure:
   ```json
   {
     "message": "Your announcement text",
     "lastUpdated": Timestamp
   }
   ```

## Key Benefits
- ✅ Shows every launch (not just first time)
- ✅ Displays admin's update timestamp (not user's launch time)
- ✅ Can be updated remotely without app update
- ✅ Ready for settings toggle later
- ✅ Works with your existing mock data system
