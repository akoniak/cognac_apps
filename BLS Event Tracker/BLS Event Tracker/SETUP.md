# Community Status App - Setup Guide

## 🚀 Getting Started

### 1. Install Firebase Dependencies

1. In Xcode, go to **File → Add Package Dependencies...**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Version: **11.0.0** or latest
4. Select these packages:
   - **FirebaseAuth**
   - **FirebaseFirestore**
   - **FirebaseStorage**

### 2. Set Up Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project (or use existing)
3. Add an iOS app:
   - Click "Add app" → iOS
   - Enter your bundle ID: **com.yourcompany.BLS-Event-Tracker**
   - Download `GoogleService-Info.plist`
4. Drag `GoogleService-Info.plist` into your Xcode project
   - ✅ Check "Copy items if needed"
   - ✅ Add to target: BLS Event Tracker

### 3. Configure Firebase Console

#### Enable Authentication:
1. Go to **Authentication → Sign-in method**
2. Enable **Apple** (requires Apple Developer account setup)
3. Enable **Email/Password**

#### Create Firestore Database:
1. Go to **Firestore Database**
2. Click **Create database**
3. Start in **production mode** (we'll add rules next)
4. Choose your region

#### Firestore Security Rules:
Replace the default rules with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isUser(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }
    
    function isModerator() {
      return getUserRole() in ['admin', 'moderator'];
    }
    
    function canSubmitReports() {
      return getUserRole() in ['admin', 'moderator', 'general'];
    }
    
    // Communities - read only for authenticated users
    match /communities/{communityId} {
      allow read: if isSignedIn();
      allow write: if false; // Managed by admin
    }
    
    // User profiles
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isUser(userId);
      allow update: if isUser(userId) || isModerator();
      allow delete: if false;
    }
    
    // Reports
    match /reports/{reportId} {
      allow read: if isSignedIn();
      allow create: if canSubmitReports();
      allow update: if isUser(resource.data.author_id) || isModerator();
      allow delete: if isModerator();
    }
  }
}
```

#### Create Initial Community:
In Firestore Console, manually create the first community document:

**Collection:** `communities`  
**Document ID:** (auto-generate)

```json
{
  "name": "your-community-name",
  "display_name": "Your Community Name",
  "description": "Mountain town community status tracker",
  "center_lat": 39.6433,
  "center_lng": -106.3781,
  "radius_meters": 5000,
  "admin_user_ids": [],
  "moderator_user_ids": [],
  "is_active": true,
  "created_at": [Timestamp - now],
  "updated_at": [Timestamp - now]
}
```

**⚠️ Important:** Update the `center_lat` and `center_lng` to your actual community's coordinates.

### 4. Add Location Permissions to Info.plist

Add these keys to your `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show your position on the community map and help you report issues accurately.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photos to attach images to status reports.</string>
```

### 5. Configure Sign in with Apple

1. Go to your [Apple Developer Account](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select your App ID
4. Enable **Sign in with Apple** capability
5. In Xcode, go to your target's **Signing & Capabilities**
6. Click **+ Capability** and add **Sign in with Apple**

### 6. Build and Run! 🎉

You should now be able to:
- ✅ Sign in with Apple or Email
- ✅ View the map
- ✅ Submit status reports
- ✅ Verify/dispute reports from others
- ✅ View your profile

---

## 📋 Next Steps (Future Enhancements)

- [ ] Add photo upload to Firebase Storage
- [ ] Implement push notifications for nearby reports
- [ ] Add report expiration background job (Cloud Functions)
- [ ] Create admin panel for managing users/communities
- [ ] Add report filtering by category
- [ ] Implement search functionality
- [ ] Add community member list (optional)
- [ ] Export/analytics for admins

---

## 🐛 Troubleshooting

### Firebase Import Errors
- Make sure you added the Firebase Swift Package
- Clean build folder: **Product → Clean Build Folder**
- Restart Xcode

### GoogleService-Info.plist Not Found
- Verify file is in project root
- Check target membership in File Inspector

### Location Not Showing
- Grant location permission when prompted
- Check device location services in Settings

### Sign in with Apple Not Working
- Verify capability is enabled in Xcode
- Check App ID configuration in Apple Developer portal
- Test on physical device (not simulator for production)

---

## 🏗️ Architecture Overview

```
App Structure:
├── Models/
│   ├── Community.swift
│   ├── UserProfile.swift
│   └── Report.swift
├── Services/
│   ├── AuthenticationManager.swift
│   ├── FirestoreService.swift
│   └── GeocodingService.swift
├── ViewModels/
│   ├── MapViewModel.swift
│   └── NewReportViewModel.swift
└── Views/
    ├── RootView.swift
    ├── AuthenticationView.swift
    ├── MainMapView.swift
    ├── NewReportView.swift
    ├── ReportDetailCard.swift
    └── ProfileView.swift
```

---

## 📝 Key Design Decisions

1. **MapKit over Google Maps:** Free, native, no API keys
2. **Address input over map pins:** Simpler, faster during emergencies
3. **Auto-expiring reports:** Keeps data fresh without manual cleanup
4. **Verification system:** Community-driven accuracy
5. **Role-based access:** Supports moderation without complexity
6. **Single community focus:** Keeps V1 simple, backend supports expansion

---

Need help? Check the code comments or ask questions!
