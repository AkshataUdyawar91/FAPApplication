# Plan: Photo Thumbnail Gallery with Validation Borders

## Goal

Add a photo thumbnail gallery at the bottom of all three submission detail pages. Photos displayed as small thumbnails inside a `Wrap` for responsiveness. Each photo gets a thick colored border — red if it has any validation error, green if all checks pass.

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
- `_dioSilent` Dio instance for fetching document bytes

## Data Source

Photos come from `_submission['campaigns'][*]['photos']` — each photo `Map<String, dynamic>`:
- `id` / `photoId` — document ID (fetch image via `/api/documents/{id}/download`)
- `fileName` — display name
- `blobUrl` — Azure blob URL (private, not directly usable from frontend)

Validation comes from `_photoValidations` list — each entry `Map<String, dynamic>`:
- `fileName` — matches photo filename
- `allPassed` (bool) — true if all checks passed
- `failureReason` (String) — non-empty if validation failed
- `validationDetailsJson` (String) — JSON with detailed rule results

## Per-Photo Validation Logic

Match each campaign photo to its validation entry by `fileName`:

| Condition | Border |
|-----------|--------|
| Matching validation found, `allPassed == true` and `failureReason` empty | 2px `AppColors.photoBorderPassed` (`#34D399` emerald-400) |
| Matching validation found, `allPassed == false` OR `failureReason` non-empty | 2px `AppColors.photoBorderFailed` (`#F87171` red-400) |
| No matching validation entry found (not yet validated) | 2px `AppColors.photoBorderPending` (`#D1D5DB` grey-300) |

## Display Order (Sorting)

Photos must be sorted so **failed validations appear first**, then passed:

1. **Red border (hasError = true)** — failed validation photos first
2. **Grey border (isPending = true)** — not yet validated photos next
3. **Green border (no error, not pending)** — passed photos last

Within each group, maintain original order from the campaigns array.

## New Shared Widget

**File**: `frontend/lib/core/widgets/photo_thumbnail_gallery.dart`

Shared across all three pages (lives in `core/widgets/` not feature-specific).

### Data Model

```dart
class PhotoThumbnailItem {
  final String documentId;
  final String fileName;
  final bool hasError;    // true = red border
  final bool isPending;   // true = grey border (no validation data yet)
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
- `Wrap(spacing: 8, runSpacing: 8)` — responsive reflow, no fixed grid
- Each thumbnail: **80×80** with `cacheWidth/cacheHeight: 160` (2x for retina)
- `ClipRRect` with `borderRadius: 8` inside a `Container` with white background and 2px border
- Border color per validation status (green / red / grey)
- Placeholder icon while image loads
- Eye icon overlay on hover (dark scrim + `Icons.visibility`)

### Thumbnail Loading Strategy
- Fetch via existing pattern: `GET /api/documents/{id}/download` → `base64Content`
- Cache decoded `Uint8List` in `Map<String, Uint8List>` on widget state
- Load in batches of 10 to avoid flooding the API
- Show `Icons.image` placeholder in grey box while loading
- On error: show `Icons.broken_image` placeholder

### Tap Behavior
- On hover: dark overlay with white eye icon (`Icons.visibility`)
- On tap → calls `onPhotoTap(documentId, fileName)` → parent calls `_viewDocument`

### Validation Matching
- Builds a `documentId → validation` lookup from `_photoValidations`
- Separates per-photo validations (documentId = photo ID) from aggregate (documentId = package ID)
- Each photo checks for its own per-photo validation first, falls back to aggregate
- If no validation exists at all → grey border (pending/not yet validated)
- Checks both `allPassed` and `allValidationsPassed` keys for compatibility

## Integration in Each Page

### 1. Helper to collect photos with validation status

Add to each page's state class (identical logic in all three):

```dart
List<PhotoThumbnailItem> _collectPhotosWithValidation() {
  final items = <PhotoThumbnailItem>[];
  final campaigns = _submission?['campaigns'] as List? ?? [];

  for (final campaign in campaigns) {
    final photos = (campaign as Map<String, dynamic>)['photos'] as List? ?? [];
    for (final photo in photos) {
      final photoMap = photo as Map<String, dynamic>;
      final fileName = photoMap['fileName']?.toString() ?? '';
      final docId = photoMap['id']?.toString()
          ?? photoMap['photoId']?.toString() ?? '';

      // Match by documentId first (per-photo), then fall back to aggregate (packageId)
      final validation = validationByDocId[docId] ?? aggregateValidation;

      final bool hasError;
      final bool isPending;
      if (validation != null) {
        isPending = false;
        final allPassed = validation['allPassed'] == true ||
            validation['allValidationsPassed'] == true;
        final failureReason = validation['failureReason']?.toString() ?? '';
        hasError = !allPassed || failureReason.isNotEmpty;
      } else {
        // No validation data — mark as pending (grey border)
        isPending = true;
        hasError = false;
      }

      if (docId.isNotEmpty) {
        items.add(PhotoThumbnailItem(
          documentId: docId,
          fileName: fileName,
          hasError: hasError,
          isPending: isPending,
        ));
      }
    }
  }

  // Sort: failed first, then pending, then passed
  items.sort((a, b) {
    int priority(PhotoThumbnailItem item) {
      if (item.hasError) return 0;   // red first
      if (item.isPending) return 1;  // grey next
      return 2;                       // green last
    }
    return priority(a).compareTo(priority(b));
  });

  return items;
}
```

### 2. Add gallery in `_buildContent` (each page)

Insert after the Validation Report section, before the bottom spacer:

```dart
// Photo Thumbnail Gallery
final galleryPhotos = _collectPhotosWithValidation();
if (galleryPhotos.isNotEmpty) ...[
  const SizedBox(height: 24),
  PhotoThumbnailGallery(
    photos: galleryPhotos,
    token: widget.token,
    onPhotoTap: (docId, fileName) => _viewDocument(docId, fileName),
  ),
],

const SizedBox(height: 80), // existing bottom spacer
```

## Visual Design

```
┌──────────────────────────────────────────────────────┐
│ 📷 Team Photos (99)                                  │
│──────────────────────────────────────────────────────│
│  Failed first:                                       │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐         │
│ │ 3px 🔴 │ │ 3px 🔴 │ │ 3px 🔴 │ │ 3px 🔴 │  ...   │
│ │  img   │ │  img   │ │  img   │ │  img   │         │
│ └────────┘ └────────┘ └────────┘ └────────┘         │
│  Then passed:                                        │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐         │
│ │ 3px 🟢 │ │ 3px 🟢 │ │ 3px 🟢 │ │ 3px 🟢 │  ...   │
│ │  img   │ │  img   │ │  img   │ │  img   │         │
│ └────────┘ └────────┘ └────────┘ └────────┘         │
│                                                      │
│ 🔴 Red border   = has validation errors (shown first)│
│ ⬜ Grey border   = pending (no validation data)       │
│ 🟢 Green border = all validations passed (shown last)│
└──────────────────────────────────────────────────────┘
```

## File Changes Summary

| File | Change |
|------|--------|
| `frontend/lib/core/theme/app_colors.dart` | Add `photoBorderPassed`, `photoBorderFailed`, `photoBorderPending` |
| `frontend/lib/core/widgets/photo_thumbnail_gallery.dart` | **NEW** — shared gallery widget + `PhotoThumbnailItem` model + `_HoverThumbnail` |
| `frontend/lib/features/submission/presentation/pages/agency_submission_detail_page.dart` | Add `_collectPhotosWithValidation()` + gallery in `_buildContent` |
| `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart` | Add `_collectPhotosWithValidation()` + gallery in `_buildContent` |
| `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart` | Add `_collectPhotosWithValidation()` + gallery in `_buildContent` |

## Performance Considerations

- 80×80 thumbnails with `cacheWidth/cacheHeight: 160` — decoded at 2x display size, not full resolution
- `Wrap` handles responsive reflow without `GridView` overhead (no scroll-within-scroll issues)
- Batch loading (10 at a time) prevents API flooding
- `Map<String, Uint8List>` cache avoids re-fetching on rebuilds; deduplicates by documentId
- `const` constructors where possible
- Hover state isolated in `_HoverThumbnail` widget to avoid rebuilding entire gallery
