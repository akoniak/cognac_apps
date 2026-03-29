# Community Status Tracker

A practical, map-based community utility app for tracking power outages, internet connectivity, and road conditions during storms and emergencies in mountain communities.

## 🎯 Purpose

This app helps small communities stay informed during emergencies by providing structured status reports on:
- **Power** (out/restored)
- **Internet** (out/restored)
- **Roads** (plowed/blocked)

It emphasizes utility over social interaction, with structured reporting, verification systems, and automatic report expiration.

## ✨ Features

### Core Functionality
- 📍 **Map-based reporting** - View all community reports on an interactive map
- 📝 **Structured reports** - Submit reports by category with location, notes, and optional photos
- ✅ **Verification system** - Community members can verify or dispute reports
- ⏰ **Auto-expiration** - Reports automatically expire based on category
- 👥 **Role-based access** - Admin, Moderator, General, and Read-Only roles
- 🔐 **Secure authentication** - Sign in with Apple or Email/Password

### User Roles
- **Admin** - Full control, user management
- **Moderator** - Can hide inappropriate reports
- **General User** - Can submit, verify, and dispute reports
- **Read Only** - Can view reports only

## 🛠️ Technology Stack

- **SwiftUI** - Modern iOS UI framework
- **MapKit** - Native Apple maps (free, no API keys)
- **Firebase Auth** - User authentication
- **Cloud Firestore** - Real-time database
- **Firebase Storage** - Photo storage (future)
- **CoreLocation** - Geocoding and location services

## 📱 Requirements

- iOS 17.0+
- Xcode 15.0+
- Firebase account (free tier is sufficient)
- Apple Developer account (for Sign in with Apple)

## 🚀 Getting Started

### Quick Start

1. **Clone and open in Xcode**
2. **Add Firebase SDK** (see SETUP.md)
3. **Download GoogleService-Info.plist** from Firebase Console
4. **Configure Firebase project** (see SETUP.md)
5. **Add Info.plist permissions** (see Info-Additions.plist)
6. **Build and run!**

For detailed setup instructions, see **[SETUP.md](./SETUP.md)**

## 📂 Project Structure

```
BLS Event Tracker/
├── Models/
│   ├── Community.swift           # Community/neighborhood model
│   ├── UserProfile.swift         # User with role-based permissions
│   └── Report.swift              # Status report model
├── Services/
│   ├── AuthenticationManager.swift  # Firebase Auth wrapper
│   ├── FirestoreService.swift       # Database operations
│   └── GeocodingService.swift       # Address geocoding
├── ViewModels/
│   ├── MapViewModel.swift           # Main map logic
│   └── NewReportViewModel.swift     # Report creation logic
├── Views/
│   ├── RootView.swift               # Root navigation
│   ├── AuthenticationView.swift    # Sign in screen
│   ├── MainMapView.swift            # Main map interface
│   ├── NewReportView.swift          # Report submission form
│   ├── ReportDetailCard.swift      # Report detail popup
│   └── ProfileView.swift            # User profile
└── App/
    ├── BLS_Event_TrackerApp.swift   # App entry point
    └── ContentView.swift             # Root content view
```

## 🗺️ Key Design Decisions

### Why MapKit over Google Maps?
- ✅ Free (no API keys or billing)
- ✅ Native iOS integration
- ✅ Excellent geocoding services
- ✅ Simpler to implement

### Why Address Input over Map Pins?
- ✅ Faster during emergencies
- ✅ Works without precise GPS
- ✅ More accessible interface
- ✅ Better for rural areas

### Why Auto-Expiring Reports?
- ✅ Keeps data fresh automatically
- ✅ No manual cleanup needed
- ✅ Different expiration times per category
- ✅ Reduces stale information

### Why Verification System?
- ✅ Community-driven accuracy
- ✅ No single source of truth needed
- ✅ Builds confidence in reports
- ✅ Helps identify outdated info

## 🔒 Privacy & Security

- All data requires authentication
- Location only used for map display (not stored)
- Optional photo upload (user controlled)
- Firestore security rules enforce access control
- Moderators can hide inappropriate content

## 🐛 Known Limitations (V1)

- Single community only (backend supports multiple)
- Photo upload not yet implemented
- No push notifications
- No offline support
- Manual report expiration (requires Cloud Function for automation)
- No search/filter functionality

## 🚧 Roadmap

### Phase 2
- [ ] Photo upload to Firebase Storage
- [ ] Push notifications for nearby reports
- [ ] Report filtering by category
- [ ] Search functionality
- [ ] Cloud Function for auto-expiration

### Phase 3
- [ ] Multi-community support in UI
- [ ] Admin dashboard
- [ ] Analytics for community admins
- [ ] Community member directory
- [ ] In-app report history

### Future Ideas
- [ ] Weather integration
- [ ] Emergency contact directory
- [ ] Service provider info (plow companies, electricians)
- [ ] Export reports to CSV
- [ ] Apple Watch app
- [ ] Widget for quick status view

## 📖 Documentation

- **[SETUP.md](./SETUP.md)** - Complete setup instructions
- **[FIRESTORE_STRUCTURE.md](./FIRESTORE_STRUCTURE.md)** - Database schema
- **Info-Additions.plist** - Required Info.plist entries

## 🤝 Contributing

This is a single-community project initially. For multi-community deployment:
1. Fork the repository
2. Update community coordinates in Firestore
3. Customize branding as needed
4. Deploy to your own Firebase project

## 📄 License

[Add your license here]

## 🙋 Support

For issues or questions:
1. Check the SETUP.md troubleshooting section
2. Review Firestore security rules
3. Verify Firebase configuration
4. Check code comments for implementation details

## 🎓 Learning Resources

- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [MapKit Documentation](https://developer.apple.com/documentation/mapkit)
- [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/)

---

Built with ❤️ for mountain communities
