# Plan: Photo Thumbnail Gallery with Validation Borders

## Goal

Add a photo thumbnail gallery at the bottom of all three submission detail pages. Photos displayed as small thumbnails inside a `Wrap` for responsiveness. Each photo gets a colored border based on its individual validation result — red for failed, green for passed, grey for pending.

## Active Border States

Currently only **3 border states** are active, matching the chatbot's pass/fail-only model:

| State | Color | Hex | When |
|-------|-------|-----|------|
| Failed | Red | `#F87171` (red-400) | Any of the 4 required rules failed |
| Pending | Grey | `#D1D5DB` (grey-300) | Submission still processing or no validation data |
| Passed | Green | `#34D399` (emerald-400) | All 4 required rules passed |

> **Dormant**: Yellow/warning infrastructure (`#FBBF24` amber-400) exists in frontend code (`hasWarning` field, `_hasWarningRules()` helper, `photoBorderWarning` color) but is never triggered because the backend sets `isWarning = false` for all 4 rules. This can be activated in the future if any rules become advisory instead of required.

## Affected Pages

| Page | File | Role |
|------|------|------|
| Agency Detail | `frontend/lib/features/submission/presentation/pages/agency_submission_detail_page.dart` | Agency |
| ASM Review Detail | `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart` | ASM |
| HQ/RA Review Detail | `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart` | RA / HQ |

All three pages already have:
- `_submission` map with `campaigns[*].photos` array
- `_photoValidations` list with per-photo validation entries
- `_viewDocument(documentId, fileName)` method for preview

## Data Source

Photos come from `_submission['campaigns'][*]['photos']` — each photo `Map<String, dynamic>`:
- `id` / `photoId` — document ID (fetch image via `/api/documents/{id}/download`)
- `fileName` — display name
- `blobUrl` — Azure blob URL (private, not directly usable from frontend)

Validation comes from `_photoValidations` list — each entry `Map<String, dynamic>`:
- `documentId` — matches photo ID (per-photo) or package ID (aggregate)
- `allPassed` (bool) — true if all required checks passed
- `failureReason` (String) — non-empty if validation failed
- `validationDetailsJson` (String) — JSON with `proactiveRules` array containing per-rule results

## Backend: Per-Photo Validation (ValidationAgent)

### Previous Behavior
The `ValidationAgent.BuildPerDocumentResults()` created only one **aggregate** validation entry for all photos combined, with `DocumentId = package.Id`. No per-photo entries existed from the standard validation pipeline.

### Current Behavior
`BuildPerDocumentResults()` now creates:
1. **Aggregate entry** (kept for backward compatibility) — `DocumentId = package.Id`, covers field presence + cross-document checks
2. **Per-photo entries** (new) — one per photo with `DocumentId = photo.Id`, based on individual EXIF metadata

### Per-Photo Validation Rules

Aligned with chatbot's `RunPhotoValidationRules` in `AssistantController.cs` — same rule codes, same data sources, same pass/fail logic.

| Rule Code | Label | isWarning | What It Checks |
|-----------|-------|-----------|----------------|
| `PHOTO_DATE_VISIBLE` | Date | `false` | Date/timestamp from EXIF or overlay |
| `PHOTO_GPS_VISIBLE` | GPS | `false` | GPS latitude/longitude from EXIF |
| `PHOTO_BLUE_TSHIRT` | Blue T-shirt | `false` | Blue t-shirt detected by AI |
| `PHOTO_3W_VEHICLE` | 3W Vehicle | `false` | 3-wheel vehicle detected by AI |

All 4 rules are **required** (`isWarning = false`). This matches the chatbot exactly — there is no warning/advisory state.

Data sources (same as chatbot):
1. Dedicated entity columns first: `photo.DateVisible`, `photo.PhotoTimestamp`, `photo.Latitude`, `photo.Longitude`, `photo.BlueTshirtPresent`, `photo.ThreeWheelerPresent`
2. Fallback to `photo.ExtractedMetadataJson` → `PhotoMetadata` deserialization

Pass/fail logic:
- `allPassed = dateVisible && gpsVisible && blueTshirt && threeWheeler` — all 4 must pass
- If any rule fails → `allPassed = false` → red border
- If all pass → `allPassed = true` → green border

## Frontend: Per-Photo Validation Logic

### State-Based Pending Check (Priority)

Before checking individual validation results, the submission state is checked first. If the submission is still being processed (state is `draft`, `uploaded`, `extracting`, or `validating`), **all photos get grey (pending) borders** regardless of any validation data that may exist.

Once the state advances to `PendingCH` or beyond, the per-photo validation matching below is used.

### Per-Photo Validation Matching

Match each campaign photo to its validation entry by `documentId`:

| Condition | Border Color |
|-----------|-------------|
| Submission still processing | 2px grey (`#D1D5DB`) |
| `allPassed == false` OR `failureReason` non-empty | 2px red (`#F87171`) |
| `allPassed == true`, no failure | 2px green (`#34D399`) |
| No matching validation entry found | 2px grey (`#D1D5DB`) |

### Dormant Warning Detection

Each page has a `_hasWarningRules(validation)` helper that parses `validationDetailsJson` and checks for rules with `isWarning == true` and `passed != true`. This code exists but currently never returns `true` because the backend sets `isWarning = false` on all rules.

## Display Order (Sorting)

1. **Red border (hasError)** — failed validation photos first
2. **Grey border (isPending)** — not yet validated photos next
3. **Green border (passed)** — all validations passed, shown last

Within each group, original order from the campaigns array is maintained.

## Shared Widget

**File**: `frontend/lib/core/widgets/photo_thumbnail_gallery.dart`

### Data Model

```dart
class PhotoThumbnailItem {
  final String documentId;
  final String fileName;
  final bool hasError;     // true = red border
  final bool hasWarning;   // true = yellow border (dormant — never set by current backend)
  final bool isPending;    // true = grey border (no validation data yet)
}
```

### Widget

```dart
class PhotoThumbnailGallery extends StatefulWidget {
  final List<PhotoThumbnailItem> photos;
  final String token;
  final void Function(String documentId, String fileName)? onPhotoTap;
}
```

### Layout
- Wrapped in a `Card` with header: `📷 Team Photos ({count})` plus failed/passed count badges
- `Wrap(spacing: 14, runSpacing: 14)` — responsive reflow
- Each thumbnail: **80×80** with `cacheWidth/cacheHeight: 160` (2x for retina)
- `ClipRRect` with `borderRadius: 8` inside a `Container` with white background and 2px border
- Border color per validation status (red / green / grey)
- Placeholder icon while image loads
- Eye icon overlay on hover (dark scrim + `Icons.visibility`)

### Header Badges
- Red badge: `{n} failed` (shown if errorCount > 0)
- Green badge: `{n} passed` (shown if passedCount > 0)
- Yellow badge: `{n} warning` (dormant — shown if warningCount > 0, but currently never triggered)

### Thumbnail Loading Strategy
- Fetch via `GET /api/documents/{id}/download` → `base64Content`
- Cache decoded `Uint8List` in `Map<String, Uint8List>` on widget state
- Load in batches of 10 to avoid flooding the API
- Show `Icons.image` placeholder while loading
- On error: show `Icons.broken_image` placeholder

### Tap Behavior
- On hover: dark overlay with white eye icon (`Icons.visibility`)
- On tap → calls `onPhotoTap(documentId, fileName)` → parent calls `_viewDocument`

## Visual Design

```
┌──────────────────────────────────────────────────────────────┐
│ 📷 Team Photos (12)                      5 failed   7 passed │
│──────────────────────────────────────────────────────────────│
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐      │
│ │ 2px 🔴 │ │ 2px 🔴 │ │ 2px 🔴 │ │ 2px 🔴 │ │ 2px 🔴 │      │
│ │  img   │ │  img   │ │  img   │ │  img   │ │  img   │      │
│ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘      │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐      │
│ │ 2px 🟢 │ │ 2px 🟢 │ │ 2px 🟢 │ │ 2px 🟢 │ │ 2px 🟢 │ ... │
│ │  img   │ │  img   │ │  img   │ │  img   │ │  img   │      │
│ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘      │
│                                                              │
│ 🔴 Red   = validation failed (any of 4 required rules)      │
│ ⬜ Grey  = pending (not yet validated)                        │
│ 🟢 Green = all validations passed                            │
└──────────────────────────────────────────────────────────────┘
```

## File Changes Summary

| File | Change |
|------|--------|
| `backend/.../Services/ValidationAgent.cs` | `BuildPerDocumentResults()` creates per-photo validation entries with 4 required rules (all `isWarning = false`), matching chatbot |
| `frontend/lib/core/theme/app_colors.dart` | `photoBorderPassed`, `photoBorderFailed`, `photoBorderPending` (active) + `photoBorderWarning` (dormant) |
| `frontend/lib/core/widgets/photo_thumbnail_gallery.dart` | Shared gallery widget with `PhotoThumbnailItem` + `_HoverThumbnail` |
| `frontend/.../agency_submission_detail_page.dart` | `_collectPhotosWithValidation()` + gallery in `_buildContent` |
| `frontend/.../asm_review_detail_page.dart` | `_collectPhotosWithValidation()` + gallery in `_buildContent` |
| `frontend/.../hq_review_detail_page.dart` | `_collectPhotosWithValidation()` + gallery in `_buildContent` |

## Performance Considerations

- 80×80 thumbnails with `cacheWidth/cacheHeight: 160` — decoded at 2x display size, not full resolution
- `Wrap` handles responsive reflow without `GridView` overhead (no scroll-within-scroll issues)
- Batch loading (10 at a time) prevents API flooding
- `Map<String, Uint8List>` cache avoids re-fetching on rebuilds; deduplicates by documentId
- `const` constructors where possible
- Hover state isolated in `_HoverThumbnail` widget to avoid rebuilding entire gallery
