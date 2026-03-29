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
- U1 submits a report; immediately deletes it (within 10 minutes, 0 verifications)
- **Expected:** Report disappears from map; U1's `report_count` **stays at the post-submission value** (i.e. does NOT revert to the pre-submission value — the submission is still counted even though the report was deleted). Grace period only prevents the *decrement* that would otherwise happen outside the window.

### Test 7.2 — Delete after grace period decrements report_count
- U1 submits a report; wait 10+ minutes; delete (still 0 verifications)
- **Expected:** U1's `report_count` −1

### Test 7.3 — Cannot delete a verified report
- U1 submits; U2 confirms; U1 tries to delete
- **Expected:** Delete blocked (`verificationCount > 0`)

### Test 7.4 — Corroborators keep points if author deletes
- U1 submits; U2 corroborates; A confirms (paying out U2's 0.5 points); attempt U1 deletion if permitted
- **Expected:** U2's `confirmed_report_points` remain intact regardless of author deletion

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
6. **6.1 → 6.2** — Confidence tier badges (builds on prior tests)
7. **5.1 → 5.2** — Trusted Reporter (needs a high-trust account; run after 8.x if starting fresh)
8. **7.1 → 7.4** — Deletion edge cases
9. **8.1 → 8.3** — Long-running score progression
