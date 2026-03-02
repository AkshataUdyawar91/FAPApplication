# Agency Dashboard - Design History

## Current Version (Latest)

### Layout
- **Header**: "Dashboard" title with "Create New Request" button on the right
- **Stats Cards** (4 cards in a row):
  - Pending Requests (blue icon)
  - Approved This Month (green icon)
  - Total Reimbursed - ₹6,60,000 (purple icon)
  - Drafts (orange icon)
- **Recent Requests Section**:
  - Title: "Recent Requests" with status filter dropdown on the right
  - Data table with columns:
    - REQ NUMBER
    - INVOICE NO.
    - SUBMITTED DATE
    - INVOICE AMT
    - STATUS (badges: Submitted, Draft, On Hold)

### Features
- Clean table layout
- Compact design
- Better space utilization
- No search bar
- Status filter dropdown only

---

## Previous Version (Before Table Layout)

### Layout
- **Sidebar**: Blue gradient sidebar with navigation
  - Logo and "Bajaj" branding
  - Navigation items: Dashboard, Upload, Notifications, Settings
  - User profile at bottom
  - Logout button
- **Header**: 
  - Title: "All Requests"
  - Subtitle: "View and track all your reimbursement requests"
  - "Create New Request" button on the right
- **Stats Cards** (5 cards in a row):
  - Total Requests (gray)
  - Pending (yellow/orange)
  - Under Review (blue)
  - Approved (green)
  - Rejected (red)
- **Filters Section**:
  - Search bar: "Search by request ID..."
  - Status dropdown: "All Statuses"
- **Requests List**:
  - Card-based layout (not table)
  - Each card showed:
    - Status icon
    - Request ID
    - Submission date
    - Document count
    - Status badge
    - Info items: Documents, Status, Last Updated

### Features
- Card-based list view
- Full search functionality
- Animated card entries
- More detailed information per request
- Status icons with colors
- Empty state with illustration

---

## Original Version (First Implementation)

### Layout
- Simple centered layout
- Basic stats cards
- Simple list of submissions
- Minimal styling
- No sidebar navigation

### Features
- Basic CRUD operations
- Simple status display
- No animations
- Basic filtering

---

## Key Differences

| Feature | Original | Previous | Current |
|---------|----------|----------|---------|
| Layout | Centered | Sidebar + Main | Sidebar + Main |
| Stats Cards | 3-4 basic | 5 colored | 4 with icons |
| Requests Display | Simple list | Animated cards | Data table |
| Search | No | Yes | No |
| Filters | Basic | Dropdown | Dropdown only |
| Navigation | None | Sidebar | Sidebar |
| Animations | No | Yes | No |
| Space Usage | Poor | Good | Excellent |

---

## Files

- **Current**: `frontend/lib/features/submission/presentation/pages/agency_dashboard_page.dart`
- **Sidebar**: Integrated in the same file
- **Routing**: `frontend/lib/main.dart`

---

## To Revert to Previous Card-Based Layout

If you want to go back to the card-based layout with search functionality, you would need to:

1. Restore the search bar in the filters section
2. Change `_buildRequestsTable()` back to `_buildRequestsList()`
3. Restore the `_buildRequestCard()` method
4. Add back the animations (TweenAnimationBuilder)
5. Restore the 5 stats cards layout
6. Add back the header subtitle

The previous version had more visual appeal with animations and cards, but used more vertical space. The current version is more compact and efficient for viewing many requests at once.
