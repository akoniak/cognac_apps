# Reputation System Test Plan

**Users:** Admin (A), User 1 (U1), User 2 (U2)

Before starting, record each user's baseline values from Firestore (`users/{uid}`):
- `report_count`
- `confirmed_report_count`
- `confirmed_report_points`
- `verification_count`

---

## Section 1: Basic Report & Confirmation

### Test 1.1 — Primary report submission increments report_count
- U1 submits a report (road + category with no existing active report)
- **Expected:** U1's `report_count` +1; no change to points

### Test 1.2 — Confirmation awards 1.0 point to author
- U2 confirms U1's report
- **Expected:** U1's `confirmed_report_points` +1.0, `confirmed_report_count` +1; U2's `verification_count` +1

### Test 1.3 — Second confirmation does NOT award more points to author
- A confirms U1's same report (U2 already confirmed)
- **Expected:** U1's `confirmed_report_points` unchanged; A's `verification_count` +1
- This verifies the per-report `author_reputation_earned` ledger prevents double-awarding

---

## Section 2: Self-Confirmation Prevention

### Test 2.1 — Author cannot confirm own report
- U1 tries to confirm their own report
- **Expected:** Action blocked — no confirm/dispute buttons visible to the author, or action silently rejected

---

## Section 3: Corroborating Reports

### Test 3.1 — Corroborating submission increments report_count, no immediate points
- With U1's active report still live, U2 submits a report for the same road + category
- **Expected:** U2's `report_count` +1, `confirmed_report_points` unchanged; U1's report shows U2 in `corroborating_submitter_ids`; `corroborators_rewarded = false`

### Test 3.2 — Corroborators receive 0.5 points on first external verification
- A (who has not yet voted) confirms the report
- **Expected:** U2's `confirmed_report_points` +0.5; `corroborators_rewarded` flips to `true`; U1 receives their +1.0 from first verification (if not already awarded); A's `verification_count` +1

### Test 3.3 — Subsequent verifications do NOT re-award corroborators
- Have another account confirm the same report after `corroborators_rewarded = true`
- **Expected:** U2's `confirmed_report_points` unchanged

### Test 3.4 — Cannot corroborate own report
- U1 tries to submit a second report for the same road + category they already reported
- **Expected:** Error: "You already have an active [category] report for this road"

### Test 3.5 — Cannot corroborate twice
- U2 tries to corroborate the same report a second time
- **Expected:** Error: "You've already corroborated this report"

---

## Section 4: Disputes & Vote Flipping

### Test 4.1 — Basic dispute does not award points to author
- Fresh report from U1; U2 disputes it
- **Expected:** U1's points unchanged; U2's `verification_count` +1; report shows 0 verifications, 1 dispute

### Test 4.2 — Flip confirm → dispute deducts points (non-road-status category)
- U2 confirms U1's power outage report (U1 gets +1.0 point)
- U2 then flips to dispute the same report
- **Expected:** U1's `confirmed_report_points` −1.0, `confirmed_report_count` −1; U2 no longer in verified list

### Test 4.3 — Flip confirm → dispute on road status does NOT penalize (exempt category)
- U2 confirms a "road blocked" or "road plowed" report from U1
- U2 then flips to dispute
- **Expected:** U1's `confirmed_report_points` **unchanged** (road status categories are exempt from penalty); dispute count increments

### Test 4.5 — Flip confirm → dispute on power out does NOT penalize (exempt category)
- U2 confirms a "power out" report from U1
- U2 then flips to dispute the same report
- **Expected:** U1's `confirmed_report_points` **unchanged** (`powerOut` now has `hasOpposingCategory = true`); dispute count increments

### Test 4.4 — Disputed status escalates at 3 disputes
- Get A, U1, and U2 to each dispute a single report (with 0 or fewer verifications than disputes)
- **Expected:** Report `status` field in Firestore changes to `"disputed"`; reflected in UI

---

## Section 4b: Power Restored Flow

### Test 4b.1 — "Power Has Been Restored" button appears on powerOut reports (non-author only)
- U1 submits a power outage report
- U2 opens the detail card for that report
- **Expected:** Three buttons shown: "Still Out" (green), "Power Has Been Restored" (blue), "Was Never Out" (red)

### Test 4b.2 — "Power Has Been Restored" removes the report from the map without penalising the author
- U2 taps "Power Has Been Restored" on U1's power out report
- **Expected:** Report immediately disappears from map; U1's `confirmed_report_points` and `confirmed_report_count` **unchanged**; U2's `verification_count` +1; report `status` in Firestore changes to `"expired"`

### Test 4b.3 — Author does NOT see the three-button layout on their own report
- U1 opens the detail card for their own power out report (which has 0 verifications)
- **Expected:** "Delete My Report" button shown; no "Still Out / Power Has Been Restored / Was Never Out" buttons

### Test 4b.4 — "Was Never Out" disputes and DOES NOT penalise the author (exempt category)
- U2 taps "Was Never Out" on U1's power out report
- **Expected:** U1's `confirmed_report_points` **unchanged** (`powerOut` is now an exempt category for reputation penalty); dispute count increments; U2's `verification_count` +1
- Contrast with Test 4.2 where a power out *confirm → dispute flip* **was** penalising — this is now fixed.

### Test 4b.5 — "Still Out" confirmation works like a standard verify
- U2 taps "Still Out" on U1's power out report
- **Expected:** U1's `confirmed_report_points` +1.0 (first confirmation), `confirmed_report_count` +1; U2's `verification_count` +1; report shows "Still Out" button as already-voted (dimmed green) if card is reopened

### Test 4b.6 — Power restored by non-author increments their verification_count
- Verify in Firestore after Test 4b.2: the user who tapped "Power Has Been Restored" has `verification_count` +1

---

## Section 4c: Road Plowed Flow

### Test 4c.1 — Three-button layout shown to non-authors on Road Plowed reports
- U1 submits a Road Plowed report
- U2 opens the detail card for that report
- **Expected:** Three buttons shown: "Still Plowed" (green), "Road Blocked" (orange), "Was Never Plowed" (red)

### Test 4c.2 — "Still Plowed" confirms the report and awards points to the author
- U2 taps "Still Plowed" on U1's Road Plowed report
- **Expected:** U1's `confirmed_report_points` +1.0, `confirmed_report_count` +1; U2's `verification_count` +1; report shows confirmation badge

### Test 4c.3 — "Road Blocked" creates a counter-report without penalising the original author
- U2 taps "Road Blocked" on U1's Road Plowed report
- **Expected:** A new `roadBlocked` report is created for the same road; U2's `report_count` +1; U1's `confirmed_report_points` and `confirmed_report_count` **unchanged**; original Road Plowed report's vote counts **unchanged**

### Test 4c.4 — "Was Never Plowed" disputes and does NOT penalise the author
- U2 taps "Was Never Plowed" on U1's Road Plowed report
- **Expected:** U1's `confirmed_report_points` **unchanged** (`roadPlowed.hasOpposingCategory = true`); dispute count increments; U2's `verification_count` +1

### Test 4c.5 — Author sees "Road Needs Plowing Again" button, not the three-button layout
- U1 opens the detail card for their own Road Plowed report
- **Expected:** "Road Needs Plowing Again" (or "Road Blocked") button visible; no Still Plowed / Road Blocked / Was Never Plowed voter buttons shown

### Test 4c.6 — Author tapping "Road Needs Plowing Again" creates a counter-report
- U1 taps the "Road Needs Plowing Again" button on their own Road Plowed report
- **Expected:** A new `roadBlocked` report is created for the same road; U1's `report_count` +1; road marker updates to reflect new status

---

## Section 4d: Road Blocked Marker Visual Feedback

### Test 4d.1 — Undisputed Road Blocked report shows red marker
- U1 submits a Road Blocked report; no one has disputed it
- **Expected:** Road marker on map is **red** (xmark icon)

### Test 4d.2 — Disputed Road Blocked report turns orange (mixed)
- U2 confirms U1's Road Blocked report, then U3 disputes it (or U2 taps "Was Never Blocked")
- **Expected:** Road marker turns **orange** (triangle icon) — matching the behavior of disputed power out markers

### Test 4d.3 — Disputes resolved back to mostly-confirmed restores red marker
- After 4d.2, additional users confirm the report until verifications > disputes and `confidenceTier` is no longer `.mixed`
- **Expected:** Road marker returns to **red**

### Test 4d.4 — Road Plowed report shows green marker (unchanged behavior)
- Confirm that submitting or confirming a Road Plowed report still shows a green checkmark marker
- **Expected:** Road marker is **green**

---

## Section 5: Trusted Reporter Auto-Verification

### Test 5.1 — High-trust author gets auto-verified badge without community confirmations
- Whichever account has `weightedTrust >= 0.8` submits a fresh report
- **Expected:** Report immediately shows green "Trusted Reporter" badge with 0 community confirmations

### Test 5.2 — Any dispute removes Trusted Reporter status
- Another user disputes the auto-verified report
- **Expected:** "Trusted Reporter" badge disappears; report falls back to standard confidence tier logic

---

## Section 6: Report Confidence Tiers

### Test 6.1 — Verified badge requires 2 confirmations, not 1
- Fresh report from U1; A confirms it; check badge (should not yet be green "Verified"); U2 confirms
- **Expected:** After 1st confirm → still Unconfirmed or single-verify state; after 2nd confirm → "Verified" green badge

### Test 6.2 — Mixed badge appears with at least 1 verify and 1 dispute
- U1 report; A confirms; U2 disputes
- **Expected:** Yellow "Mixed" badge

---

## Section 7: Report Deletion

### Test 7.1 — Delete within 10-minute grace period leaves stats unchanged
- U1 submits a report; immediately deletes it (within 10 minutes, 0 verifications, no corroborators)
- **Expected:** Report disappears from map; U1's `report_count` **stays at the post-submission value** (i.e. does NOT revert to the pre—submission value — the submission is still counted even though the report was deleted). Grace period only prevents the *decrement* that would otherwise happen outside the window.

### Test 7.2 — Delete after grace period decrements report_count
- U1 submits a report; wait 10+ minutes; delete (still 0 verifications, no corroborators)
− **Expected:** U1's `report_count` −1

### Test 7.3 — Cannot delete a confirmed report
- U1 submits; U2 confirms; U1 tries to delete
- **Expected:** Delete blocked (`verificationCount > 0`); "Delete My Report" button is hidden; server-side guard also rejects the attempt if the UI is stale

### Test 7.3b — Cannot delete a corroborated report
- U1 submits; U2 corroborates (same road + category, triggering the corroborating path); U1 tries to delete
- **Expected:** Delete blocked (`corroboratingSubmitterIDs` non-empty); "Delete My Report" button is hidden in both the detail card and the activity list; server-side guard rejects any race-condition attempt; error message reads "This report has been corroborated or confirmed by another user and can no longer be deleted."
- Verify in Firestore: report document still exists; U2 still in `corroborating_submitter_ids`

### Test 7.4 — Corroborators keep points after first verification
- U1 submits; U2 corroborates; A confirms (paying out U2's 0.5 points)
- **Expected:** U2's `confirmed_report_points` +0.5, `corroborators_rewarded = true`; U1 cannot delete (blocked by both corroboration and confirmation at this point)

---

## Section 8: Weighted Trust Score Progression

### Test 8.1 — Accuracy percent matches points/count ratio
- After several reports, open the profile view and verify:
  `accuracy % = confirmed_report_points / report_count` (clamped to 100%)

### Test 8.2 — Confidence weight follows sqrt curve
- New user at 0 reports: submit 5 → confidence weight ≈ 0.50 (`sqrt(5/20)`)
- Submit 15 more (20 total) → confidence weight = 1.0

### Test 8.3 — Weighted trust tier transitions are visible in profile
- Track a user across sessions: "New Reporter" → "Building Reputation" → "Trusted" → "Highly Trusted"
- Thresholds: < 0.2 / 0.2–0.49 / 0.5–0.79 / ≥ 0.8

---

## Firestore Fields to Verify After Each Test

**User profile** (`users/{uid}`):

| Field | Description |
|---|---|
| `report_count` | Total reports submitted (primary + corroborating) |
| `confirmed_report_count` | Distinct reports that earned ≥ 1 point |
| `confirmed_report_points` | Total weighted points (1.0 primary, 0.5 corroborating) |
| `verification_count` | Total verify/dispute actions cast |

**Report document** (`communities/{cid}/reports/{rid}`):

| Field | Description |
|---|---|
| `corroborating_submitter_ids` | UIDs of corroborators |
| `corroborators_rewarded` | True once corroborators have been paid out |
| `author_reputation_earned` | Exact points credited to author from this report |
| `verified_by` / `disputed_by` | Arrays of voter UIDs |
| `verification_count` / `dispute_count` | Aggregate vote counts |
| `author_weighted_trust` | Trust snapshot at submission (drives Trusted Reporter badge) |
| `status` | Escalates to `"disputed"` at 3+ disputes > verifications |

---

## Suggested Test Order

1. **1.1 → 1.3** — Baseline confirm flow
2. **2.1** — Self-confirm guard
3. **3.1 → 3.5** — Corroboration
4. **4.1 → 4.5** — Disputes and vote flipping (includes power-out exempt category)
5. **4b.1 → 4b.6** — Power restored flow
6. **4c.1 → 4c.6** — Road Plowed three-button flow and counter-report
7. **4d.1 → 4d.4** — Road Blocked marker visual feedback (orange when disputed)
8. **6.1 → 6.2** — Confidence tier badges (builds on prior tests)
9. **5.1 → 5.2** — Trusted Reporter (needs a high-trust account; run after 8.x if starting fresh)
10. **7.1 → 7.4** — Deletion edge cases
11. **8.1 → 8.3** — Long-running score progression
