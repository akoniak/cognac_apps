# Firestore Database Structure

## Collections

### 1. `communities` Collection

Stores information about each community/neighborhood.

```javascript
{
  "name": "vail-community",                    // Unique identifier
  "display_name": "Vail Mountain Community",   // Display name
  "description": "Mountain town near Vail",    // Description
  "center_lat": 39.6433,                       // Center latitude
  "center_lng": -106.3781,                     // Center longitude
  "radius_meters": 5000,                       // Approximate radius
  "admin_user_ids": ["userId1"],               // Array of admin UIDs
  "moderator_user_ids": ["userId2"],           // Array of moderator UIDs
  "is_active": true,                           // Active flag
  "created_at": Timestamp,                     // Creation time
  "updated_at": Timestamp,                     // Last update time
  "settings": {}                               // Optional settings map
}
```

### 2. `users` Collection

User profiles with roles and permissions. Document ID = Firebase Auth UID.

```javascript
{
  "email": "user@example.com",                 // User email
  "display_name": "John Doe",                  // Display name
  "community_id": "communityDocId",            // Community reference
  "role": "general",                           // admin | moderator | general | read_only
  "address": "123 Main St",                    // Optional home address
  "phone_number": "+15551234567",              // Optional phone
  "created_at": Timestamp,                     // Account creation
  "last_active_at": Timestamp,                 // Last seen
  "is_active": true,                           // Account active
  "is_banned": false,                          // Banned flag
  "ban_reason": null,                          // Ban reason if applicable
  "report_count": 0,                           // Number of reports submitted
  "verification_count": 0                      // Number of verifications made
}
```

### 3. `reports` Collection

Status reports from users. Auto-generated document IDs.

```javascript
{
  "community_id": "communityDocId",            // Community reference
  "category": "power_out",                     // Report category
  "status": "active",                          // active | expired | disputed | removed
  "address": "123 Main St, Vail, CO",          // Formatted address
  "latitude": 39.6433,                         // Location latitude
  "longitude": -106.3781,                      // Location longitude
  "note": "Power out since 3pm",               // Optional note
  "photo_url": "gs://bucket/path/image.jpg",   // Optional photo URL
  "author_id": "userUid",                      // Author UID
  "author_display_name": "John Doe",           // Author name (denormalized)
  "verification_count": 5,                     // Number of verifications
  "dispute_count": 1,                          // Number of disputes
  "verified_by_user_ids": ["uid1", "uid2"],    // Array of verifier UIDs
  "disputed_by_user_ids": ["uid3"],            // Array of disputer UIDs
  "created_at": Timestamp,                     // Report creation time
  "expires_at": Timestamp,                     // Expiration time
  "updated_at": Timestamp,                     // Last update time
  "is_hidden": false,                          // Hidden by moderator
  "hidden_by_moderator_id": null,              // Moderator UID if hidden
  "hidden_reason": null                        // Reason for hiding
}
```

## Report Categories

- `power_out` - Power Out
- `power_on` - Power On
- `internet_out` - Internet Out
- `internet_on` - Internet On
- `road_plowed` - Road Plowed
- `road_blocked` - Road Blocked/Not Plowed

## User Roles

- `admin` - Full control, can manage users and communities
- `moderator` - Can moderate reports and hide inappropriate content
- `general` - Can submit, verify, and dispute reports
- `read_only` - Can only view reports

## Report Statuses

- `active` - Currently active and visible
- `expired` - Past expiration time (auto-managed)
- `disputed` - High dispute count relative to verifications
- `removed` - Hidden by moderator

## Indexes Required

Create these composite indexes in Firestore:

1. **Reports by Community and Status**
   - Collection: `reports`
   - Fields: `community_id` (Ascending), `status` (Ascending), `expires_at` (Ascending)

2. **Reports by Community (Active)**
   - Collection: `reports`
   - Fields: `community_id` (Ascending), `is_hidden` (Ascending), `status` (Ascending), `expires_at` (Descending)

## Security Rules Summary

- All data requires authentication
- Users can read all data in their community
- Users can create their own profile
- Users with `general` role or above can create reports
- Users can update their own reports
- Moderators can update/hide any report
- Admins can manage users

## Initial Setup Checklist

- [ ] Create a community document
- [ ] Configure security rules
- [ ] Create composite indexes (Firestore will prompt you)
- [ ] Enable Authentication providers
- [ ] Test with a user account

## Future Enhancements

### Potential Collections:
- `notifications` - Push notification tracking
- `community_invites` - Invitation system for new members
- `report_history` - Audit log for report changes
- `analytics` - Usage statistics

### Potential Cloud Functions:
- Auto-expire old reports (runs hourly)
- Send push notifications for nearby reports
- Clean up old data (90+ days)
- Generate daily/weekly community reports
