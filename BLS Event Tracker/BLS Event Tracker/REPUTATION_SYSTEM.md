# Reputation System

This document describes how user reputation is calculated, stored, and displayed in the BLS Event Tracker app.

---

## Overview

Each user has a reputation score called **Weighted Trust** (0–1). It reflects both the *accuracy* of their reports and how much *confidence* can be placed in that accuracy given their submission volume. New users start with low trust that grows as they build a track record.

---

## Stored Fields (Firestore: `users/{uid}`)

| Field | Type | Description |
|---|---|---|
| `report_count` | Int | Total reports submitted (primary + corroborating) |
| `verification_count` | Int | Total verify/dispute actions this user has cast |
| `confirmed_report_count` | Int | Number of the user's reports that have ever earned at least one reputation point (incremented once per report when `authorReputationEarned` first goes above 0; decremented when it returns to 0) |
| `confirmed_report_points` | Double | Total weighted reputation points earned across all reports |

## Reputation Fields on Report Documents (Firestore: `communities/{cid}/reports/{rid}`)

| Field | Type | Description |
|---|---|---|
| `corroborating_weight` | Double | Point weight for the author per verification: 1.0 primary, 0.5 corroborating |
| `corroborating_submitter_ids` | [String] | UIDs of users who corroborated this report (deferred payout) |
| `corroborators_rewarded` | Bool | True once corroborators have been paid their 0.5 points |
| `author_reputation_earned` | Double | Exact points credited to the author from this report; kept in sync by every vote transaction; used by delete to subtract precisely the right amount |
| `author_weighted_trust` | Double | Snapshot of the author's `weightedTrust` at the moment of submission. Used by `confidenceTier` to grant auto-Verified status without community confirmations |

---

## How Points Are Earned

### Primary Report (first report for a road + category)
- Submitted via the normal "New Report" flow when no active report already exists for that road and category.
- `report_count` +1 on submission.
- When another user **confirms** it: `confirmed_report_count` +1, `confirmed_report_points` +1.0.

### Corroborating Report (duplicate road + category already active)
- Triggered automatically when a user submits a report and an active report for the same road+category already exists.
- The submitter's UID is appended to the report's `corroborating_submitter_ids` array (a new field on the report document).
- `report_count` +1 on submission.
- **Points are deferred** — the 0.5 `confirmed_report_points` award is NOT given immediately. It is paid out when the first external verifier confirms the parent report (see "First Verification Payout" below). This removes the pile-on farming incentive: joining a report is worthless if no one else ever confirms it.

### Confirming Another User's Report
- `verification_count` +1 for the voter.
- `confirmed_report_count` +1 and `confirmed_report_points` +weight for the report's author.
  - weight = 1.0 for primary reports, 0.5 for corroborating reports (stored as `corroborating_weight` on the report).

### First Verification Payout (corroborators)
- When `verifyReport` is called and `corroborators_rewarded == false` on the report, this is the first external verification.
- Every UID in `corroborating_submitter_ids` receives `confirmed_report_points` +0.5 in that same transaction.
- `corroborators_rewarded` is set to `true` on the report document, preventing any future verification from re-awarding those points.
- The verifier themselves is excluded from the payout even if they are in the corroborator list.

---

## How Points Are Lost

### Flipping from Confirm → Dispute (power outage reports only)
When a user who previously confirmed a **power outage** report changes their vote to "Not Accurate":
- Author's `confirmed_report_count` −1 (floored at 0).
- Author's `confirmed_report_points` −weight (floored at 0.0).

### Road status reports are exempt from reputation penalties
Road categories (`roadBlocked`, `roadPlowed`) have natural opposing categories — if someone disputes a "Road Blocked" report it most likely means the road has since been plowed, not that the original reporter was wrong. Flipping confirm→dispute on a road status report does **not** deduct points from the author. The dispute count still increments (affecting the report's confidence tier badge), but the author's reputation is unaffected.

### Author deletes their own report
An author can delete a report they submitted via the "Delete My Report" button (visible only to the author on the detail card and activity list row), **but only while `verificationCount == 0`**. Once any other user has confirmed the report the button is hidden — the report is considered community-validated and cannot be unilaterally removed by the author.

Delete accounting uses the report's `author_reputation_earned` ledger (a per-report field kept in sync by `verifyReport` and `disputeReport`) rather than reconstructing from vote counts. This guarantees the subtraction is always exact regardless of vote-flips or the corroboration mix.

**Within 10-minute grace period:**
- User profile is left **completely untouched** — `report_count`, `confirmed_report_count`, and `confirmed_report_points` all remain as-is.
- The report document is deleted and disappears from the map.
- Stats reflect that the report was submitted; only the visible report is gone.

**After 10-minute grace period:**
- `report_count` −1.
- If `authorReputationEarned > 0`: `confirmed_report_count` −1 and `confirmed_report_points` − `authorReputationEarned` (floored at 0).
- Corroborators keep their 0.5 points — they had no control over the author's decision to delete.

The grace window is purely a map-cleanup tool: it lets a user remove an accidental submission without affecting other users' feeds, but it does not rewrite their own stats.

---

## Computed Reputation Values

All computed values live in `ModelsUserProfile.swift` and are derived from the stored fields above.

### Accuracy Percent
```
accuracyPercent = min(confirmedReportPoints / reportCount, 1.0)
```
Ratio of weighted confirmation points to total reports submitted (primary + corroborating). Clamped to 1.0. Since corroborating submissions now increment `report_count`, the denominator always matches the numerator's scale.

### Confidence Weight
```
confidenceWeight = min(sqrt(reportCount / 20), 1.0)
```
Ramps from 0 → 1 over the first 20 reports using a square-root curve (fast early growth, flattening near the cap). Using sqrt instead of a linear ramp is critical: the old linear ramp `count/20` cancelled algebraically with `1/count` inside accuracyPercent, collapsing the entire formula to `points/20` and making accuracy irrelevant. The sqrt ramp does not cancel.

### Weighted Trust
```
weightedTrust = accuracyPercent × confidenceWeight
```
Primary reputation score, 0–1. A perfectly accurate reporter at 5 reports gets trust ≈ 0.50; at 20 reports, trust = 1.0 × 1.0 = 1.0. An inaccurate reporter at high volume is penalised by low accuracy.

---

## Trust Tiers (Profile View)

| Weighted Trust | Label | Color |
|---|---|---|
| ≥ 0.8 | Highly Trusted | Green |
| 0.5 – 0.79 | Trusted | Blue |
| 0.2 – 0.49 | Building Reputation | Orange |
| < 0.2 | New Reporter | Secondary/Gray |

The profile view also displays:
- **Accuracy** as a percentage with a `(confirmed / total)` breakdown.
- A **progress bar** whose fill width is proportional to `weightedTrust`.

---

## Anti-Farming Protections

- A user cannot confirm or dispute their own report (blocked in `verifyReport` / `disputeReport`).
- A user **cannot corroborate their own report** — attempting to submit a duplicate road+category report when the active report was authored by the same user shows an error ("You already have an active … report for this road") and is blocked. Enforced client-side in `NewReportViewModel` and also server-side inside the `submitCorroboratingReport` transaction.
- A user **cannot corroborate the same report twice** — a second attempt shows an error ("You've already corroborated this report"). Enforced client-side in `NewReportViewModel` and server-side in the transaction.
- A user can only confirm or dispute a report once; switching from confirm→dispute (or vice versa) is a single flip, not a double-count.
- Corroborating submissions earn only 0.5 points (vs 1.0 for primary reports) to reduce incentive for pile-on voting.
- The confidence weight ramp means high accuracy from a tiny sample does not yield high trust.

---

## Report Confidence Tiers

These are per-report indicators (distinct from per-user reputation) shown as badges in the report detail card.

| Tier | Condition | Color |
|---|---|---|
| Trusted Reporter (green) | Author `weightedTrust` ≥ 0.8 **and** 0 disputes | Green |
| Verified (green) | ≥ 2 community verifications **and** 0 disputes | Green |
| Mixed (yellow) | ≥ 1 verification and ≥ 1 dispute (any ratio) | Yellow |
| Unconfirmed (red) | 0 verifications, or exactly 1 verification with no disputes | Red |

**Trusted Reporter:** Reports from users in the Highly Trusted tier (`weightedTrust ≥ 0.8`) get a distinct green "Trusted Reporter" badge without requiring community confirmations. Any dispute removes this status and the report falls through to normal tier logic.

A report with ≥ 3 disputes and more disputes than verifications is also marked `status = disputed` in Firestore.

---

## Key Source Files

| File | Responsibility |
|---|---|
| `ModelsUserProfile.swift` | Stored fields and computed reputation properties |
| `ModelsReport.swift` | `corroboratingWeight`, `corroboratingSubmitterIDs`, `corroboratorsRewarded`, `authorWeightedTrust`, `confidenceTier`, `hasOpposingCategory` |
| `ServicesFirebaseDataService.swift` | `verifyReport`, `disputeReport`, `submitCorroboratingReport`, `deleteOwnReport` transactions |
| `ServicesMockDataService.swift` | In-memory mirror of Firebase reputation logic (used in mock/dev mode) |
| `ViewModelsNewReportViewModel.swift` | Primary vs corroborating submission logic |
| `ViewsProfileView.swift` | `ReputationRow` UI, trust tier labels and colours |
| `ViewsReportDetailCard.swift` | Confirm/Dispute buttons, `ConfidenceTierBadge` |
