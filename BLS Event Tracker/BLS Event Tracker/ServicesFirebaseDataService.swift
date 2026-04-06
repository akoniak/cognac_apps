//
//  FirebaseDataService.swift
//  BLS Event Tracker
//
//  Firestore-backed data service. Drop-in replacement for MockDataService.
//  All method signatures are identical so view models only need to swap
//  `MockDataService.shared` → `FirebaseDataService.shared`.
//

import Foundation
import FirebaseFirestore

@MainActor
class FirebaseDataService {
    static let shared = FirebaseDataService()

    private let db = Firestore.firestore()

    // MARK: - Real-time listener state

    /// The active Firestore snapshot listener registration, if any.
    private var reportsListenerRegistration: ListenerRegistration?
    /// The community currently being listened to.
    private var listeningCommunityID: String?
    /// Callbacks invoked whenever Firestore pushes a new snapshot.
    /// Keyed by an opaque UUID token returned to each subscriber, so individual
    /// callbacks can be removed without affecting other subscribers.
    private var reportsUpdateCallbacks: [UUID: ([Report]) -> Void] = [:]
    /// The most recent snapshot delivered to subscribers, so late-registering
    /// subscribers receive data immediately without waiting for the next push.
    private var lastKnownReports: [Report] = []

    private init() {}

    // MARK: - Real-time listener

    /// Registers a callback and ensures the Firestore listener is running for the given community.
    /// Returns an opaque token that must be passed to stopListeningToReports to remove this
    /// specific callback. Multiple callers can each register their own callback — all are notified.
    /// If reports are already cached the new callback is called immediately with current data.
    /// Calling with a different communityID tears down the existing listener and re-attaches.
    @discardableResult
    func startListeningToReports(for communityID: String, onUpdate: @escaping ([Report]) -> Void) -> UUID {
        let token = UUID()
        reportsUpdateCallbacks[token] = onUpdate

        // If we're already listening to this community, deliver the cached snapshot
        // immediately so the new subscriber doesn't show an empty list while waiting
        // for the next Firestore push.
        if communityID == listeningCommunityID {
            if !lastKnownReports.isEmpty {
                onUpdate(lastKnownReports)
            }
            return token
        }

        // New community — tear down old listener and start fresh
        reportsListenerRegistration?.remove()
        reportsListenerRegistration = nil
        listeningCommunityID = communityID
        lastKnownReports = []

        let query = reportsRef(communityID: communityID)
            .whereField("status", isEqualTo: "active")
            .whereField("is_hidden", isEqualTo: false)
            .whereField("expires_at", isGreaterThan: Timestamp(date: Date()))

        reportsListenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                print("Reports listener error: \(error)")
                return
            }
            guard let snapshot else { return }
            let reports = (try? snapshot.documents.compactMap {
                try self.decodeReport(id: $0.documentID, data: $0.data())
            }) ?? []
            // Firestore calls this on an arbitrary thread; dispatch to main
            DispatchQueue.main.async {
                self.lastKnownReports = reports
                self.reportsUpdateCallbacks.values.forEach { $0(reports) }
            }
        }
        return token
    }

    /// Removes the callback associated with the given token.
    /// The Firestore listener is torn down only when no subscribers remain.
    func stopListeningToReports(token: UUID) {
        reportsUpdateCallbacks.removeValue(forKey: token)
        guard reportsUpdateCallbacks.isEmpty else { return }
        reportsListenerRegistration?.remove()
        reportsListenerRegistration = nil
        listeningCommunityID = nil
        lastKnownReports = []
    }

    // MARK: - Collection paths

    private var communitiesRef: CollectionReference {
        db.collection("communities")
    }

    private func reportsRef(communityID: String) -> CollectionReference {
        db.collection("communities").document(communityID).collection("reports")
    }

    private func userProfilesRef() -> CollectionReference {
        db.collection("users")
    }

    private var announcementRef: DocumentReference {
        db.collection("config").document("announcement")
    }

    // MARK: - Community Operations

    func fetchDefaultCommunityID() async throws -> String {
        let snapshot = try await communitiesRef
            .whereField("is_active", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw DataServiceError.noCommunityFound
        }
        return doc.documentID
    }

    func fetchCommunity(communityID: String) async throws -> Community {
        let doc = try await communitiesRef.document(communityID).getDocument()
        guard doc.exists, let data = doc.data() else {
            throw DataServiceError.noCommunityFound
        }
        return try decodeCommunity(id: doc.documentID, data: data)
    }

    // MARK: - User Profile Operations

    func fetchUserProfile(userID: String) async throws -> UserProfile {
        let doc = try await userProfilesRef().document(userID).getDocument()
        guard doc.exists, let data = doc.data() else {
            throw DataServiceError.userNotFound
        }
        return try decodeUserProfile(id: doc.documentID, data: data)
    }

    func fetchAllUsersInCommunity(communityID: String) async throws -> [UserProfile] {
        let snapshot = try await userProfilesRef()
            .whereField("community_id", isEqualTo: communityID)
            .getDocuments()
        return try snapshot.documents.compactMap {
            try decodeUserProfile(id: $0.documentID, data: $0.data())
        }
    }

    func createUserProfile(_ profile: UserProfile) async throws {
        guard let userID = profile.id else {
            throw DataServiceError.invalidUserID
        }
        let data = try encodeUserProfile(profile)
        try await userProfilesRef().document(userID).setData(data)
    }

    func updateUserProfile(_ profile: UserProfile) async throws {
        guard let userID = profile.id else {
            throw DataServiceError.invalidUserID
        }
        let data = try encodeUserProfile(profile)
        try await userProfilesRef().document(userID).setData(data, merge: true)
    }

    func deleteUserProfile(userID: String) async throws {
        try await userProfilesRef().document(userID).delete()
    }

    /// Anonymizes all reports authored by the given user so personal identifiers
    /// are removed when an account is deleted. Sets author_id to "deleted" and
    /// removes author_display_name from every report in the user's community.
    func anonymizeReports(authorID: String, communityID: String) async throws {
        let snapshot = try await reportsRef(communityID: communityID)
            .whereField("author_id", isEqualTo: authorID)
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.updateData([
                "author_id": "deleted",
                "author_display_name": FieldValue.delete()
            ])
        }
    }

    // MARK: - Report Operations

    func fetchReports(for communityID: String, includeExpired: Bool = false) async throws -> [Report] {
        var query: Query = reportsRef(communityID: communityID)
            .whereField("status", isEqualTo: "active")
            .whereField("is_hidden", isEqualTo: false)

        if !includeExpired {
            query = query.whereField("expires_at", isGreaterThan: Timestamp(date: Date()))
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { doc in
            try decodeReport(id: doc.documentID, data: doc.data())
        }
    }

    func createReport(_ report: Report) async throws -> String {
        guard !report.communityID.isEmpty else {
            throw DataServiceError.invalidReportID
        }
        let data = try encodeReport(report)
        let ref = try await reportsRef(communityID: report.communityID).addDocument(data: data)
        return ref.documentID
    }

    /// Atomically increments a user's report_count by 1 using a server-side increment,
    /// avoiding the read-modify-write pattern that can overwrite reputation fields.
    func incrementReportCount(userID: String) async throws {
        try await userProfilesRef().document(userID).updateData([
            "report_count": FieldValue.increment(Int64(1))
        ])
    }

    /// Returns the first active, non-hidden, non-expired report for the given road and category, if any.
    func fetchActiveReportForRoad(roadID: String, category: ReportCategory, communityID: String) async throws -> Report? {
        let snapshot = try await reportsRef(communityID: communityID)
            .whereField("road_id", isEqualTo: roadID)
            .whereField("category", isEqualTo: category.rawValue)
            .whereField("status", isEqualTo: "active")
            .whereField("is_hidden", isEqualTo: false)
            .whereField("expires_at", isGreaterThan: Timestamp(date: Date()))
            .limit(to: 1)
            .getDocuments()
        return try snapshot.documents.first.map { try decodeReport(id: $0.documentID, data: $0.data()) }
    }

    /// Records a corroborating submission: adds the submitter to the report's
    /// corroboratingSubmitterIDs list and increments their report_count.
    ///
    /// The 0.5 reputation point award is intentionally deferred — corroborators earn
    /// their points only when the parent report receives its first external verification
    /// (see verifyReport). This prevents farming points by pile-on without any validation.
    func submitCorroboratingReport(existingReportID: String, communityID: String, submitterID: String) async throws {
        let reportRef = reportsRef(communityID: communityID).document(existingReportID)
        let submitterRef = db.collection("users").document(submitterID)

        _ = try await db.runTransaction { transaction, errorPointer in
            let reportSnap: DocumentSnapshot
            let submitterSnap: DocumentSnapshot
            do {
                reportSnap    = try transaction.getDocument(reportRef)
                submitterSnap = try transaction.getDocument(submitterRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard let reportData = reportSnap.data() else { return nil }

            // Block the author from corroborating their own report
            let authorID = reportData["author_id"] as? String ?? ""
            guard submitterID != authorID else { return nil }

            // Prevent duplicate corroboration entries
            var corroborators = reportData["corroborating_submitter_ids"] as? [String] ?? []
            guard !corroborators.contains(submitterID) else { return nil }

            corroborators.append(submitterID)
            transaction.updateData([
                "corroborating_submitter_ids": corroborators,
                "updated_at": Timestamp(date: Date())
            ], forDocument: reportRef)

            // Increment report_count so the confidence ramp and accuracy ratio
            // reflect the true total number of submissions by this user.
            // Points are NOT awarded yet — they come when the report is first verified.
            let rc = submitterSnap.data()?["report_count"] as? Int ?? 0
            transaction.updateData(["report_count": rc + 1], forDocument: submitterRef)

            return nil
        }
    }

    func updateReport(_ report: Report) async throws {
        guard let reportID = report.id else {
            throw DataServiceError.invalidReportID
        }
        let data = try encodeReport(report)
        try await reportsRef(communityID: report.communityID).document(reportID).setData(data, merge: true)
    }

    func verifyReport(reportID: String, communityID: String, userID: String, authorID: String) async throws {
        let reportRef = reportsRef(communityID: communityID).document(reportID)
        let voterRef  = db.collection("users").document(userID)
        let authorRef = db.collection("users").document(authorID)

        _ = try await db.runTransaction { [self] transaction, errorPointer in
            // --- READ PHASE (all reads must precede writes in a Firestore transaction) ---
            let reportSnap: DocumentSnapshot
            let voterSnap:  DocumentSnapshot
            let authorSnap: DocumentSnapshot
            do {
                reportSnap = try transaction.getDocument(reportRef)
                voterSnap  = try transaction.getDocument(voterRef)
                authorSnap = try transaction.getDocument(authorRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard let reportData = reportSnap.data() else { return nil }

            // Determine whether corroborators need to be paid out on this verification.
            // They are rewarded once — the first time the report gets any external verification.
            let alreadyRewarded = reportData["corroborators_rewarded"] as? Bool ?? false
            let wasAlreadyVerified = (reportData["verified_by_user_ids"] as? [String] ?? []).contains(userID)
            let isFirstVerification = !alreadyRewarded && !wasAlreadyVerified

            // Read each corroborator's profile doc if we're about to pay them out.
            // Firestore requires all reads before writes, so we do this now.
            var corroboratorSnaps: [(String, DocumentSnapshot)] = []
            if isFirstVerification {
                let corroboratorIDs = reportData["corroborating_submitter_ids"] as? [String] ?? []
                for cid in corroboratorIDs where cid != userID {
                    let ref = self.db.collection("users").document(cid)
                    if let snap = try? transaction.getDocument(ref) {
                        corroboratorSnaps.append((cid, snap))
                    }
                }
            }

            // --- WRITE PHASE ---

            // Remove from disputed, add to verified
            var disputed = reportData["disputed_by_user_ids"] as? [String] ?? []
            var verified = reportData["verified_by_user_ids"] as? [String] ?? []
            let wasDisputingBefore = disputed.contains(userID)
            disputed.removeAll { $0 == userID }
            if !wasAlreadyVerified { verified.append(userID) }

            // Compute author reputation update values before building reportUpdates,
            // so author_reputation_earned can be included in a single report write.
            var authorUpdates: [String: Any] = [:]
            if !wasAlreadyVerified && userID != authorID {
                let weight = reportData["corroborating_weight"] as? Double ?? 1.0
                let earned = reportData["author_reputation_earned"] as? Double ?? 0.0
                let isFirstEarnedForReport = earned == 0.0

                let cc = authorSnap.data()?["confirmed_report_count"] as? Int ?? 0
                let pts = authorSnap.data()?["confirmed_report_points"] as? Double ?? 0.0

                // confirmed_report_count counts distinct reports that have earned points,
                // not confirmation events. Only increment it the first time this report
                // earns anything (i.e. when authorReputationEarned goes 0 → positive).
                authorUpdates["confirmed_report_points"] = pts + weight
                if isFirstEarnedForReport {
                    authorUpdates["confirmed_report_count"] = cc + 1
                }
            }

            var reportUpdates: [String: Any] = [
                "disputed_by_user_ids": disputed,
                "verified_by_user_ids": verified,
                "verification_count": verified.count,
                "dispute_count": disputed.count,
                "updated_at": Timestamp(date: Date())
            ]
            // Mark corroborators as rewarded so subsequent verifications don't re-award them
            if isFirstVerification {
                reportUpdates["corroborators_rewarded"] = true
            }
            // Include author_reputation_earned in the same write to avoid a duplicate
            // updateData call on reportRef, which would overwrite the earlier write.
            if !wasAlreadyVerified && userID != authorID {
                let weight = reportData["corroborating_weight"] as? Double ?? 1.0
                let earned = reportData["author_reputation_earned"] as? Double ?? 0.0
                reportUpdates["author_reputation_earned"] = earned + weight
            }
            transaction.updateData(reportUpdates, forDocument: reportRef)

            // Increment the voter's verification_count once per unique action
            if !wasAlreadyVerified {
                let vc = voterSnap.data()?["verification_count"] as? Int ?? 0
                _ = wasDisputingBefore // already removed from disputed above
                transaction.updateData(["verification_count": vc + 1], forDocument: voterRef)
            }

            // Credit the report author if this is a new verification.
            // Use corroborating_weight (1.0 for primary, 0.5 for corroborating reports).
            if !authorUpdates.isEmpty {
                transaction.updateData(authorUpdates, forDocument: authorRef)
            }

            // Pay out deferred corroboration points (0.5 each) on the first verification.
            if isFirstVerification {
                for (cid, snap) in corroboratorSnaps {
                    let ref = self.db.collection("users").document(cid)
                    let pts = snap.data()?["confirmed_report_points"] as? Double ?? 0.0
                    transaction.updateData(["confirmed_report_points": pts + 0.5], forDocument: ref)
                }
            }

            return nil
        }
    }

    func disputeReport(reportID: String, communityID: String, userID: String, authorID: String) async throws {
        let reportRef = reportsRef(communityID: communityID).document(reportID)
        let voterRef  = db.collection("users").document(userID)
        let authorRef = db.collection("users").document(authorID)

        _ = try await db.runTransaction { transaction, errorPointer in
            let reportSnap: DocumentSnapshot
            let voterSnap:  DocumentSnapshot
            let authorSnap: DocumentSnapshot
            do {
                reportSnap = try transaction.getDocument(reportRef)
                voterSnap  = try transaction.getDocument(voterRef)
                authorSnap = try transaction.getDocument(authorRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard let reportData = reportSnap.data() else { return nil }

            var disputed = reportData["disputed_by_user_ids"] as? [String] ?? []
            var verified = reportData["verified_by_user_ids"] as? [String] ?? []

            let wasPreviousVerifier = verified.contains(userID)
            let wasAlreadyDisputing = disputed.contains(userID)
            verified.removeAll { $0 == userID }
            if !wasAlreadyDisputing { disputed.append(userID) }

            // Build the report fields — we add to this dict before the single write.
            var reportUpdates: [String: Any] = [
                "disputed_by_user_ids": disputed,
                "verified_by_user_ids": verified,
                "verification_count": verified.count,
                "dispute_count": disputed.count,
                "updated_at": Timestamp(date: Date())
            ]
            if disputed.count > verified.count && disputed.count >= 3 {
                reportUpdates["status"] = "disputed"
            }

            // Revoke the author's credit if this user flipped from verify→dispute,
            // but ONLY for categories without a natural opposing category (e.g. powerOut).
            // Road status categories (roadBlocked, roadPlowed) have opposing categories —
            // a dispute most likely means "the opposite is now true", not that the
            // original reporter was wrong, so their reputation should not be penalised.
            let categoryRaw = reportData["category"] as? String ?? ""
            let category = ReportCategory(rawValue: categoryRaw)
            let shouldPenaliseReputation = category?.hasOpposingCategory == false

            if wasPreviousVerifier && userID != authorID && shouldPenaliseReputation {
                let weight = reportData["corroborating_weight"] as? Double ?? 1.0
                let earned = reportData["author_reputation_earned"] as? Double ?? 0.0
                let newEarned = max(0.0, earned - weight)

                let cc = authorSnap.data()?["confirmed_report_count"] as? Int ?? 0
                let pts = authorSnap.data()?["confirmed_report_points"] as? Double ?? 0.0

                // Only decrement confirmed_report_count when the report goes from
                // having earned points to zero — it should count distinct reports,
                // not individual confirmation events.
                var authorUpdates: [String: Any] = ["confirmed_report_points": max(0.0, pts - weight)]
                if earned > 0 && newEarned == 0.0 {
                    authorUpdates["confirmed_report_count"] = max(0, cc - 1)
                }
                transaction.updateData(authorUpdates, forDocument: authorRef)

                // Include the ledger update in the same report write
                reportUpdates["author_reputation_earned"] = newEarned
            }

            // Single write for all report updates
            transaction.updateData(reportUpdates, forDocument: reportRef)

            // Increment voter's verification_count for a new dispute action
            if !wasAlreadyDisputing {
                let vc = voterSnap.data()?["verification_count"] as? Int ?? 0
                transaction.updateData(["verification_count": vc + 1], forDocument: voterRef)
            }

            return nil
        }
    }

    /// Deletes a report the current user authored.
    ///
    /// Reputation accounting uses the report's `author_reputation_earned` ledger field —
    /// the exact points credited to the author from this specific report — rather than
    /// reconstructing from verificationCount × weight (which was unreliable).
    ///
    /// - Within 10-minute grace period: the user profile is left completely untouched.
    ///   The report disappears from the map but report_count and points are unchanged.
    ///   This is the coherent "Option B" — stats reflect that the report was submitted.
    /// - After the grace period: `report_count` −1, `confirmed_report_count` −1 (if any
    ///   points were earned), and `confirmed_report_points` reduced by exactly
    ///   `authorReputationEarned`. Corroborators keep their points.
    func deleteOwnReport(reportID: String, communityID: String, authorID: String) async throws {
        let reportRef = reportsRef(communityID: communityID).document(reportID)
        let authorRef = db.collection("users").document(authorID)

        // Captured outside the transaction closure so we can throw a typed Swift error
        // after the transaction completes — errorPointer doesn't reliably bridge custom
        // Swift errors back through Firestore's ObjC transaction machinery.
        var blockedByConfirmation = false

        _ = try await db.runTransaction { transaction, errorPointer in
            let reportSnap: DocumentSnapshot
            let authorSnap: DocumentSnapshot
            do {
                reportSnap = try transaction.getDocument(reportRef)
                authorSnap = try transaction.getDocument(authorRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard let reportData = reportSnap.data() else { return nil }

            // Block deletion if the report has been corroborated or confirmed — the server-side
            // check catches the race where the UI card was open before either event arrived.
            let liveVerificationCount = reportData["verification_count"] as? Int ?? 0
            let liveCorroborators = reportData["corroborating_submitter_ids"] as? [String] ?? []
            if liveVerificationCount > 0 || !liveCorroborators.isEmpty {
                blockedByConfirmation = true
                return nil
            }

            // Determine if within the 10-minute grace window
            let createdAt = (reportData["created_at"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let ageSeconds = Date().timeIntervalSince(createdAt)
            let withinGrace = ageSeconds <= 600 // 10 minutes

            if withinGrace {
                // Grace period: leave the user profile completely untouched.
                // The report vanishes from the map but all stats (report_count, points)
                // remain — consistent and unexploitable.
            } else {
                // Outside grace period: reverse exactly what this report contributed.
                let reportCount = authorSnap.data()?["report_count"] as? Int ?? 0
                var profileUpdates: [String: Any] = [
                    "report_count": max(0, reportCount - 1)
                ]
                let earned = reportData["author_reputation_earned"] as? Double ?? 0.0
                if earned > 0 {
                    let cc = authorSnap.data()?["confirmed_report_count"] as? Int ?? 0
                    let pts = authorSnap.data()?["confirmed_report_points"] as? Double ?? 0.0
                    profileUpdates["confirmed_report_count"] = max(0, cc - 1)
                    profileUpdates["confirmed_report_points"] = max(0.0, pts - earned)
                }
                transaction.updateData(profileUpdates, forDocument: authorRef)
            }

            transaction.deleteDocument(reportRef)
            return nil
        }

        // Throw after the transaction so callers can show a specific error message.
        if blockedByConfirmation {
            throw DataServiceError.reportAlreadyConfirmed
        }

        // Update local cache immediately
        lastKnownReports.removeAll { $0.id == reportID }
        reportsUpdateCallbacks.values.forEach { $0(lastKnownReports) }
    }

    /// Marks a power outage report as resolved (power has been restored).
    /// The report status is set to "expired" so it disappears from the map.
    /// The original author's reputation is NOT penalised — power was out when reported;
    /// it has simply since been restored.
    func markPowerRestored(reportID: String, communityID: String, resolvedByUserID: String) async throws {
        let reportRef = reportsRef(communityID: communityID).document(reportID)
        let resolverRef = db.collection("users").document(resolvedByUserID)
        try await reportRef.updateData([
            "status": ReportStatus.expired.rawValue,
            "updated_at": Timestamp(date: Date())
        ])
        // Credit the resolver with a verification_count increment for the community action
        try await resolverRef.updateData([
            "verification_count": FieldValue.increment(Int64(1))
        ])
    }

    /// Writes a user-submitted issue flag to the top-level `issue_reports` collection.
    /// Admins can review these in the Firebase console; no email is sent.
    /// reportID is optional — if nil, the report is still identifiable via the other fields.
    func submitIssueReport(reportID: String?, communityID: String, category: String, address: String, authorID: String, reportedByUserID: String, reason: String, note: String?) async throws {
        var data: [String: Any] = [
            "community_id": communityID,
            "category": category,
            "address": address,
            "author_id": authorID,
            "reported_by_user_id": reportedByUserID,
            "reason": reason,
            "created_at": Timestamp(date: Date())
        ]
        if let reportID {
            data["report_id"] = reportID
        }
        if let note, !note.isEmpty {
            data["note"] = note
        }
        try await db.collection("issue_reports").addDocument(data: data)
    }

    func hideReport(reportID: String, communityID: String, moderatorID: String, reason: String) async throws {
        let reportRef = reportsRef(communityID: communityID).document(reportID)
        try await reportRef.updateData([
            "is_hidden": true,
            "hidden_by_moderator_id": moderatorID,
            "hidden_reason": reason,
            "updated_at": Timestamp(date: Date())
        ])
    }

    func deleteReports(in communityID: String, olderThan date: Date) async throws {
        let snapshot = try await reportsRef(communityID: communityID)
            .whereField("created_at", isLessThan: Timestamp(date: date))
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
        // Clear stale cache entries — the listener will repopulate with remaining reports.
        lastKnownReports = lastKnownReports.filter { $0.createdAt >= date }
        reportsUpdateCallbacks.values.forEach { $0(lastKnownReports) }
    }

    func deleteAllReports(in communityID: String) async throws {
        let snapshot = try await reportsRef(communityID: communityID).getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
        // Immediately clear the cache and push an empty list to all subscribers
        // so the map and activity list update without waiting for the next listener push.
        lastKnownReports = []
        reportsUpdateCallbacks.values.forEach { $0([]) }
    }

    // MARK: - Announcement Operations

    func fetchAnnouncement() async throws -> Announcement {
        let doc = try await announcementRef.getDocument()
        guard doc.exists, let data = doc.data(),
              let message = data["message"] as? String else {
            throw DataServiceError.announcementNotFound
        }
        let timestamp = (data["last_updated"] as? Timestamp)?.dateValue() ?? Date()
        return Announcement(message: message, lastUpdated: timestamp)
    }

    func updateAnnouncement(_ announcement: Announcement) async throws {
        try await announcementRef.setData([
            "message": announcement.message,
            "last_updated": Timestamp(date: announcement.lastUpdated)
        ])
    }

    /// Attaches a real-time Firestore listener to the announcement document.
    /// The callback is invoked immediately with the current value and again
    /// whenever an admin saves a new announcement on any device.
    func startListeningToAnnouncement(onUpdate: @escaping (Announcement) -> Void) -> ListenerRegistration {
        announcementRef.addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data(),
                  let message = data["message"] as? String else { return }
            let timestamp = (data["last_updated"] as? Timestamp)?.dateValue() ?? Date()
            onUpdate(Announcement(message: message, lastUpdated: timestamp))
        }
    }

    // MARK: - Private Helpers

    /// Fetches the communityID for a report by doing a collection group query.
    /// This is only needed for verify/dispute/hide which receive only the reportID.
    private func communityIDForReport(reportID: String) async throws -> String {
        let snapshot = try await db.collectionGroup("reports")
            .whereField(FieldPath.documentID(), isEqualTo: reportID)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw DataServiceError.invalidReportID
        }
        // Path is: communities/{communityID}/reports/{reportID}
        let pathComponents = doc.reference.path.components(separatedBy: "/")
        guard pathComponents.count >= 2 else {
            throw DataServiceError.invalidReportID
        }
        return pathComponents[1]
    }

    // MARK: - Encoding

    private func encodeReport(_ report: Report) throws -> [String: Any] {
        [
            "community_id": report.communityID,
            "category": report.category.rawValue,
            "status": report.status.rawValue,
            "address": report.address,
            "latitude": report.latitude,
            "longitude": report.longitude,
            "road_id": report.roadID as Any,
            "note": report.note as Any,
            "photo_url": report.photoURL as Any,
            "author_id": report.authorID,
            "author_display_name": report.authorDisplayName as Any,
            "verification_count": report.verificationCount,
            "dispute_count": report.disputeCount,
            "verified_by_user_ids": report.verifiedByUserIDs,
            "disputed_by_user_ids": report.disputedByUserIDs,
            "created_at": Timestamp(date: report.createdAt),
            "expires_at": Timestamp(date: report.expiresAt),
            "updated_at": Timestamp(date: report.updatedAt),
            "is_hidden": report.isHidden,
            "hidden_by_moderator_id": report.hiddenByModeratorID as Any,
            "hidden_reason": report.hiddenReason as Any,
            "corroborating_weight": report.corroboratingWeight,
            "corroborating_submitter_ids": report.corroboratingSubmitterIDs,
            "corroborators_rewarded": report.corroboratorsRewarded,
            "author_reputation_earned": report.authorReputationEarned,
            "author_weighted_trust": report.authorWeightedTrust
        ]
    }

    private func encodeUserProfile(_ profile: UserProfile) throws -> [String: Any] {
        [
            "email": profile.email as Any,
            "display_name": profile.displayName as Any,
            "community_id": profile.communityID,
            "role": profile.role.rawValue,
            "created_at": Timestamp(date: profile.createdAt),
            "last_active_at": Timestamp(date: profile.lastActiveAt),
            "is_active": profile.isActive,
            "is_banned": profile.isBanned,
            "ban_reason": profile.banReason as Any,
            "report_count": profile.reportCount,
            "verification_count": profile.verificationCount,
            "confirmed_report_count": profile.confirmedReportCount,
            "confirmed_report_points": profile.confirmedReportPoints
        ]
    }

    // MARK: - Decoding

    private func decodeReport(id: String, data: [String: Any]) throws -> Report {
        guard let communityID = data["community_id"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = ReportCategory(rawValue: categoryRaw),
              let statusRaw = data["status"] as? String,
              let status = ReportStatus(rawValue: statusRaw),
              let address = data["address"] as? String,
              let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double,
              let authorID = data["author_id"] as? String,
              let createdAt = (data["created_at"] as? Timestamp)?.dateValue(),
              let expiresAt = (data["expires_at"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updated_at"] as? Timestamp)?.dateValue()
        else {
            throw DataServiceError.invalidReportID
        }

        return Report(
            id: id,
            communityID: communityID,
            category: category,
            status: status,
            address: address,
            latitude: latitude,
            longitude: longitude,
            roadID: data["road_id"] as? String,
            note: data["note"] as? String,
            photoURL: data["photo_url"] as? String,
            authorID: authorID,
            authorDisplayName: data["author_display_name"] as? String,
            verificationCount: data["verification_count"] as? Int ?? 0,
            disputeCount: data["dispute_count"] as? Int ?? 0,
            verifiedByUserIDs: data["verified_by_user_ids"] as? [String] ?? [],
            disputedByUserIDs: data["disputed_by_user_ids"] as? [String] ?? [],
            createdAt: createdAt,
            expiresAt: expiresAt,
            updatedAt: updatedAt,
            isHidden: data["is_hidden"] as? Bool ?? false,
            hiddenByModeratorID: data["hidden_by_moderator_id"] as? String,
            hiddenReason: data["hidden_reason"] as? String,
            corroboratingWeight: data["corroborating_weight"] as? Double ?? 1.0,
            corroboratingSubmitterIDs: data["corroborating_submitter_ids"] as? [String] ?? [],
            corroboratorsRewarded: data["corroborators_rewarded"] as? Bool ?? false,
            authorReputationEarned: data["author_reputation_earned"] as? Double ?? 0.0,
            authorWeightedTrust: data["author_weighted_trust"] as? Double ?? 0.0
        )
    }

    private func decodeCommunity(id: String, data: [String: Any]) throws -> Community {
        // Helper to read a numeric field as Double regardless of whether Firestore
        // stored it as a double or int64 (int64 comes back as Swift Int, not Double).
        func toDouble(_ key: String) -> Double? {
            if let d = data[key] as? Double { return d }
            if let i = data[key] as? Int { return Double(i) }
            return nil
        }

        guard let name = data["name"] as? String,
              let displayName = data["display_name"] as? String,
              let description = data["description"] as? String,
              let centerLat = toDouble("center_lat"),
              let centerLng = toDouble("center_lng"),
              let radius = toDouble("radius_meters")
        else {
            throw DataServiceError.noCommunityFound
        }

        // Timestamps are optional — fall back to now if not present
        let createdAt = (data["created_at"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updated_at"] as? Timestamp)?.dateValue() ?? Date()

        return Community(
            id: id,
            name: name,
            displayName: displayName,
            description: description,
            centerLatitude: centerLat,
            centerLongitude: centerLng,
            radiusMeters: radius,
            adminUserIDs: data["admin_user_ids"] as? [String] ?? [],
            moderatorUserIDs: data["moderator_user_ids"] as? [String] ?? [],
            isActive: data["is_active"] as? Bool ?? true,
            createdAt: createdAt,
            updatedAt: updatedAt,
            settings: data["settings"] as? [String: String]
        )
    }

    private func decodeUserProfile(id: String, data: [String: Any]) throws -> UserProfile {
        guard let communityID = data["community_id"] as? String else {
            throw DataServiceError.userNotFound
        }
        guard let roleRaw = data["role"] as? String, let role = UserRole(rawValue: roleRaw) else {
            throw DataServiceError.userNotFound
        }

        // Timestamps are optional — fall back to now if not present
        let createdAt = (data["created_at"] as? Timestamp)?.dateValue() ?? Date()
        let lastActiveAt = (data["last_active_at"] as? Timestamp)?.dateValue() ?? Date()

        return UserProfile(
            id: id,
            email: data["email"] as? String,
            displayName: data["display_name"] as? String,
            communityID: communityID,
            role: role,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            isActive: data["is_active"] as? Bool ?? true,
            isBanned: data["is_banned"] as? Bool ?? false,
            banReason: data["ban_reason"] as? String,
            reportCount: data["report_count"] as? Int ?? 0,
            verificationCount: data["verification_count"] as? Int ?? 0,
            confirmedReportCount: data["confirmed_report_count"] as? Int ?? 0,
            // Firestore may store this as Int if set manually in the console — handle both
            confirmedReportPoints: (data["confirmed_report_points"] as? Double)
                ?? Double(data["confirmed_report_points"] as? Int ?? 0)
        )
    }
}
