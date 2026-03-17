# Styling Adjustments Guide

Quick reference for common styling adjustments to the Enhanced Validation Report UI.

## File to Edit

`frontend/lib/features/approval/presentation/widgets/enhanced_validation_report_widget.dart`

## Common Adjustments

### 1. Confidence Score Colors

**Location**: `_buildConfidenceCard` method (around line 100)

```dart
// Current colors
if (confidence >= 85) {
  confidenceColor = Colors.green;
  confidenceIcon = Icons.check_circle;
} else if (confidence >= 70) {
  confidenceColor = Colors.orange;
  confidenceIcon = Icons.warning;
} else if (confidence >= 50) {
  confidenceColor = Colors.deepOrange;
  confidenceIcon = Icons.error_outline;
} else {
  confidenceColor = Colors.red;
  confidenceIcon = Icons.cancel;
}

// To use Bajaj brand colors:
if (confidence >= 85) {
  confidenceColor = const Color(0xFF10B981);  // Green
  confidenceIcon = Icons.check_circle;
} else if (confidence >= 70) {
  confidenceColor = const Color(0xFFF59E0B);  // Orange
  confidenceIcon = Icons.warning;
} else if (confidence >= 50) {
  confidenceColor = const Color(0xFFEF4444);  // Red-Orange
  confidenceIcon = Icons.error_outline;
} else {
  confidenceColor = const Color(0xFFDC2626);  // Dark Red
  confidenceIcon = Icons.cancel;
}
```

### 2. Card Elevation and Shadows

**Location**: Throughout the file

```dart
// Current
Card(
  elevation: 2,
  // ...
)

// For more prominent cards
Card(
  elevation: 4,
  // ...
)

// For flat design
Card(
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: BorderSide(color: Colors.grey[300]!),
  ),
  // ...
)
```

### 3. Border Radius

**Location**: Various `BorderRadius.circular()` calls

```dart
// Current (8px radius)
borderRadius: BorderRadius.circular(8),

// For more rounded corners
borderRadius: BorderRadius.circular(12),

// For sharp corners
borderRadius: BorderRadius.circular(4),

// For pill-shaped
borderRadius: BorderRadius.circular(999),
```

### 4. Spacing and Padding

**Location**: Throughout the file

```dart
// Current spacing
const EdgeInsets.all(16),
const SizedBox(height: 12),

// For tighter spacing
const EdgeInsets.all(12),
const SizedBox(height: 8),

// For looser spacing
const EdgeInsets.all(20),
const SizedBox(height: 16),
```

### 5. Font Sizes

**Location**: Text widgets throughout

```dart
// Current
style: Theme.of(context).textTheme.titleLarge?.copyWith(
  fontWeight: FontWeight.bold,
),

// To customize size
style: Theme.of(context).textTheme.titleLarge?.copyWith(
  fontSize: 24,  // Explicit size
  fontWeight: FontWeight.bold,
),

// For smaller text
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  fontSize: 14,
),
```

### 6. Severity Colors

**Location**: `_buildValidationCategoryCard` method (around line 250)

```dart
// Current
switch (category.severity.toLowerCase()) {
  case 'critical':
    severityColor = Colors.red;
    break;
  case 'high':
    severityColor = Colors.orange;
    break;
  case 'medium':
    severityColor = Colors.amber;
    break;
  default:
    severityColor = Colors.blue;
}

// To use custom colors
switch (category.severity.toLowerCase()) {
  case 'critical':
    severityColor = const Color(0xFFDC2626);  // Dark red
    break;
  case 'high':
    severityColor = const Color(0xFFF59E0B);  // Orange
    break;
  case 'medium':
    severityColor = const Color(0xFFFBBF24);  // Amber
    break;
  default:
    severityColor = const Color(0xFF3B82F6);  // Blue
}
```

### 7. Dialog Size

**Location**: `validation_report_dialog.dart` (around line 30)

```dart
// Current (90% of screen)
Container(
  width: MediaQuery.of(context).size.width * 0.9,
  height: MediaQuery.of(context).size.height * 0.9,
  // ...
)

// For larger dialog
Container(
  width: MediaQuery.of(context).size.width * 0.95,
  height: MediaQuery.of(context).size.height * 0.95,
  // ...
)

// For smaller dialog
Container(
  width: MediaQuery.of(context).size.width * 0.85,
  height: MediaQuery.of(context).size.height * 0.85,
  // ...
)

// For fixed max width
Container(
  width: MediaQuery.of(context).size.width * 0.9,
  constraints: const BoxConstraints(maxWidth: 1200),
  height: MediaQuery.of(context).size.height * 0.9,
  // ...
)
```

### 8. Button Styling

**Location**: `view_validation_report_button.dart`

```dart
// Current
ElevatedButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
)

// To customize
ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFF003087),  // Bajaj blue
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  ),
  elevation: 2,
)
```

### 9. Icon Sizes

**Location**: Throughout the file

```dart
// Current
Icon(Icons.assessment, size: 28),

// For larger icons
Icon(Icons.assessment, size: 32),

// For smaller icons
Icon(Icons.assessment, size: 24),
```

### 10. Opacity and Transparency

**Location**: Various background colors

```dart
// Current
color: confidenceColor.withOpacity(0.1),

// For more transparent
color: confidenceColor.withOpacity(0.05),

// For more opaque
color: confidenceColor.withOpacity(0.15),
```

## Quick Styling Presets

### Preset 1: Minimal Flat Design

```dart
// Cards
Card(
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(4),
    side: BorderSide(color: Colors.grey[300]!),
  ),
)

// Borders
borderRadius: BorderRadius.circular(4),

// Spacing
const EdgeInsets.all(12),
const SizedBox(height: 8),
```

### Preset 2: Bold Material Design

```dart
// Cards
Card(
  elevation: 4,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
)

// Borders
borderRadius: BorderRadius.circular(12),

// Spacing
const EdgeInsets.all(20),
const SizedBox(height: 16),
```

### Preset 3: Compact Design

```dart
// Cards
Card(
  elevation: 1,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(6),
  ),
)

// Borders
borderRadius: BorderRadius.circular(6),

// Spacing
const EdgeInsets.all(10),
const SizedBox(height: 6),

// Font sizes
fontSize: 12,  // Body text
fontSize: 16,  // Headings
```

## Testing After Adjustments

After making styling changes:

1. **Hot Reload**: Press `r` in the Flutter terminal
2. **Hot Restart**: Press `R` if hot reload doesn't work
3. **Full Rebuild**: Stop and restart `flutter run` if needed

## Common Styling Issues

### Issue: Colors don't match brand guidelines
**Solution**: Use exact hex colors from brand guidelines:
```dart
const Color(0xFF003087)  // Bajaj primary blue
const Color(0xFF00A3E0)  // Bajaj secondary blue
```

### Issue: Text is too small/large
**Solution**: Adjust font sizes explicitly:
```dart
style: TextStyle(fontSize: 16),  // Explicit size
```

### Issue: Spacing feels cramped
**Solution**: Increase padding and spacing:
```dart
const EdgeInsets.all(20),
const SizedBox(height: 16),
```

### Issue: Cards look too flat/too elevated
**Solution**: Adjust elevation:
```dart
Card(elevation: 2),  // Subtle shadow
Card(elevation: 4),  // More prominent
Card(elevation: 0),  // Flat with border
```

## Bajaj Brand Colors Reference

```dart
// Primary Colors
const primaryBlue = Color(0xFF003087);
const secondaryBlue = Color(0xFF00A3E0);

// Status Colors
const successGreen = Color(0xFF10B981);
const warningOrange = Color(0xFFF59E0B);
const errorRed = Color(0xFFEF4444);

// Neutral Colors
const backgroundGray = Color(0xFFF3F4F6);
const borderGray = Color(0xFFE5E7EB);
const textPrimary = Color(0xFF111827);
const textSecondary = Color(0xFF6B7280);
```

## Need More Help?

If you need to make more complex styling changes:
1. Check Flutter documentation: https://docs.flutter.dev/
2. Check Material Design guidelines: https://material.io/
3. Use Flutter DevTools for visual debugging
4. Test on multiple screen sizes

## Revert Changes

If you need to revert styling changes:
```bash
git checkout frontend/lib/features/approval/presentation/widgets/enhanced_validation_report_widget.dart
```
