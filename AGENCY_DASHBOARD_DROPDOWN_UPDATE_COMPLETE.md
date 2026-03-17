# Agency Dashboard Dynamic Status Dropdown - Complete

## Requirement
Show only status values in the dropdown that actually exist in the current grid data. If "Extracting" status has no records, don't show it in the dropdown to prevent users from selecting filters that result in empty grids.

## Solution Implemented

### Dynamic Dropdown Population
The dropdown now dynamically builds its options based on the actual data present in `_requests`:

1. **Always shows "All Status"** - Default option to see everything
2. **Only shows statuses that have data** - Prevents empty grid selections
3. **Maintains logical order** - Statuses appear in workflow order
4. **Auto-resets filter** - If current filter becomes unavailable after data refresh, resets to "All Status"

## Implementation Details

### 1. Added `_availableStatuses` Getter
Scans all requests and builds a set of available status values:

```dart
List<String> get _availableStatuses {
  final statuses = <String>{'all'}; // Always include 'all'
  
  for (var req in _requests) {
    final state = req['state']?.toString().toLowerCase() ?? '';
    
    // Map backend states to dropdown values
    if (['extracting', 'validating', ...].contains(state)) {
      statuses.add('extracting');
    }
    // ... other mappings
  }
  
  return statuses.toList();
}
```

### 2. Added `_buildDropdownItems()` Method
Builds dropdown items only for available statuses in the correct order:

```dart
List<DropdownMenuItem<String>> _buildDropdownItems() {
  final availableStatuses = _availableStatuses;
  final statusLabels = {
    'all': 'All Status',
    'extracting': 'Extracting',
    'pending_with_asm': 'Pending with ASM',
    'pending_with_ra': 'Pending with RA',
    'approved': 'Approved',
    'rejected_by_asm': 'Rejected by ASM',
    'rejected_by_ra': 'Rejected by RA',
  };
  
  // Define the order we want statuses to appear
  final orderedKeys = ['all', 'extracting', 'pending_with_asm', ...];
  
  return orderedKeys
      .where((key) => availableStatuses.contains(key))
      .map((key) => DropdownMenuItem<String>(
            value: key,
            child: Text(statusLabels[key]!),
          ))
      .toList();
}
```

### 3. Updated Dropdown Widgets
Changed both dropdown instances (mobile and desktop) to use dynamic items:

```dart
items: _buildDropdownItems(),  // Instead of const [...]
```

### 4. Added Auto-Reset Logic
Updated `_loadRequests()` to reset filter if it's no longer available:

```dart
// Reset filter to 'all' if current filter is not available in the new data
if (!_availableStatuses.contains(_statusFilter)) {
  _statusFilter = 'all';
}
```

## Example Scenarios

### Scenario 1: New Agency with Only Pending Requests
**Data**: 5 requests, all in "PendingASMApproval" state

**Dropdown shows**:
- All Status
- Pending with ASM

**Dropdown does NOT show**: Extracting, Pending with RA, Approved, Rejected by ASM, Rejected by RA

### Scenario 2: Agency with Mixed Statuses
**Data**: 
- 3 requests in "PendingASMApproval"
- 2 requests in "Approved"
- 1 request in "RejectedByASM"

**Dropdown shows**:
- All Status
- Pending with ASM
- Approved
- Rejected by ASM

**Dropdown does NOT show**: Extracting, Pending with RA, Rejected by RA

### Scenario 3: All Requests Approved
**Data**: 10 requests, all "Approved"

**Dropdown shows**:
- All Status
- Approved

**Dropdown does NOT show**: All other statuses

### Scenario 4: Filter Reset After Data Change
**Before refresh**: User has "Rejected by RA" filter selected (2 requests visible)
**After refresh**: Those 2 requests are now "Approved"
**Result**: Filter automatically resets to "All Status" and shows all requests

## Benefits

✅ **Better UX** - Users never see empty grids from selecting unavailable filters
✅ **Cleaner UI** - Dropdown only shows relevant options
✅ **Self-documenting** - Dropdown tells users what statuses exist in their data
✅ **Automatic** - No manual configuration needed, adapts to data
✅ **Prevents confusion** - Users won't wonder why a filter shows nothing

## Files Modified

`frontend/lib/features/submission/presentation/pages/agency_dashboard_page.dart`
- Added `_availableStatuses` getter
- Added `_buildDropdownItems()` method
- Updated both dropdown widgets to use dynamic items
- Updated `_loadRequests()` to auto-reset invalid filters

## Testing Checklist

- [ ] Dropdown shows only "All Status" and "Approved" when all requests are approved
- [ ] Dropdown shows only statuses present in current data
- [ ] Dropdown maintains logical order (workflow sequence)
- [ ] "All Status" is always present
- [ ] Selecting a status filters the grid correctly
- [ ] Grid refreshes immediately on selection
- [ ] After data refresh, if current filter is gone, it resets to "All Status"
- [ ] Empty data shows only "All Status" in dropdown
- [ ] Mixed data shows all relevant statuses

## Status
✅ **COMPLETE** - Dropdown now dynamically shows only statuses that exist in the grid data, preventing empty grid selections.
