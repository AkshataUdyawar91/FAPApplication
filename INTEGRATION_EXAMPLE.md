# Integration Example: Adding Validation Report Button to ASM Review Page

## Quick Integration Guide

### Step 1: Import the Button Widget

Add this import at the top of `asm_review_page.dart`:

```dart
import '../widgets/view_validation_report_button.dart';
```

### Step 2: Add Button to Document Card

Find where you display document cards (likely in a ListView or GridView), and add the button to the actions row:

```dart
// Example: In your document card widget
Card(
  child: ListTile(
    title: Text(document['poNumber'] ?? 'N/A'),
    subtitle: Text('Status: ${document['state']}'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Existing buttons (Approve, Reject, etc.)
        IconButton(
          icon: Icon(Icons.check),
          onPressed: () => _approveDocument(document['id']),
        ),
        IconButton(
          icon: Icon(Icons.close),
          onPressed: () => _rejectDocument(document['id']),
        ),
        
        // NEW: Add validation report button
        ViewValidationReportButton(
          packageId: document['id'],
          isCompact: true, // Use icon-only for compact display
        ),
      ],
    ),
  ),
)
```

### Step 3: Wrap with ProviderScope (if not already)

Ensure your app is wrapped with `ProviderScope` in `main.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### Step 4: Test

1. Run the backend: `dotnet run` in `backend` directory
2. Run the frontend: `flutter run -d chrome` in `frontend` directory
3. Login as ASM user
4. Navigate to a submission
5. Click the "View AI Report" button
6. Verify the validation report loads correctly

## Alternative: Full Button in Detail View

If you have a detail view for submissions, use the full button:

```dart
// In submission detail page
Column(
  children: [
    // ... document details ...
    
    SizedBox(height: 16),
    
    // Full button with text
    ViewValidationReportButton(
      packageId: packageId,
      isCompact: false,
    ),
    
    // ... other actions ...
  ],
)
```

## Troubleshooting

### Error: "No provider found"
- Ensure `ProviderScope` wraps your app in `main.dart`
- Check that you're using `ConsumerWidget` or `Consumer` if accessing providers

### Error: "Failed to load validation report"
- Verify backend is running on `http://localhost:5000`
- Check that the API endpoint exists: `GET /api/submissions/{id}/validation-report`
- Verify JWT token is valid and user has ASM or HQ role
- Check browser console for network errors

### Button not showing
- Verify import statement is correct
- Check that `packageId` is not null
- Ensure the widget is in the widget tree

### Dialog not opening
- Check for any console errors
- Verify `ValidationReportDialog.show()` is being called
- Ensure context is valid

## Example: Complete Document Card with Validation Report

```dart
import 'package:flutter/material.dart';
import '../widgets/view_validation_report_button.dart';

class DocumentCard extends StatelessWidget {
  final Map<String, dynamic> document;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PO: ${document['poNumber'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('Status: ${document['state']}'),
            Text('Submitted: ${document['createdAt']}'),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View AI Report Button
                ViewValidationReportButton(
                  packageId: document['id'],
                  isCompact: false,
                ),
                SizedBox(width: 8),
                
                // Approve Button
                ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: Icon(Icons.check),
                  label: Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                SizedBox(width: 8),
                
                // Reject Button
                ElevatedButton.icon(
                  onPressed: onReject,
                  icon: Icon(Icons.close),
                  label: Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

## Summary

The integration is simple:
1. Import the button widget
2. Add it to your document card/detail view
3. Pass the `packageId`
4. Choose compact (icon) or full (button with text) mode

The button handles everything else: opening the dialog, loading the report, displaying errors, and refresh functionality.
