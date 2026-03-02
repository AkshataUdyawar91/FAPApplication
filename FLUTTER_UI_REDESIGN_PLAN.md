# Flutter UI Redesign Plan - Based on Figma Design

## Overview
Recreate the React/shadcn UI design in Flutter while maintaining the same visual design, colors, and user experience.

## Design System from Figma

### Colors
- **Primary Blue**: #0066FF (Blue 600)
- **Background**: #F9FAFB (Gray 50)
- **Card Background**: #FFFFFF
- **Text Primary**: #111827 (Gray 900)
- **Text Secondary**: #6B7280 (Gray 500)
- **Border**: #E5E7EB (Gray 200)

### Status Colors
- **Pending**: Yellow (#FEF3C7 bg, #92400E text)
- **Under Review**: Blue (#DBEAFE bg, #1E40AF text)
- **Approved**: Green (#D1FAE5 bg, #065F46 text)
- **Rejected**: Red (#FEE2E2 bg, #991B1B text)

### Typography
- **Font Family**: Inter (system default in Flutter)
- **Heading 1**: 24px, Bold
- **Heading 2**: 20px, Bold
- **Heading 3**: 18px, Semibold
- **Body**: 16px, Regular
- **Small**: 14px, Regular

### Border Radius
- **Cards**: 10px
- **Buttons**: 8px
- **Inputs**: 8px
- **Badges**: 6px

## Pages to Implement

### 1. Login Page ✅ Priority
- Role tabs (Agency, ASM, HQ)
- Email and password fields
- Gradient background
- Modern card design

### 2. Agency Dashboard
- Stats cards with icons
- Request list with status badges
- Search and filter functionality
- Animated card entries

### 3. Agency Upload
- Multi-step document upload
- Drag and drop zones
- Progress indicators
- Document preview

### 4. ASM Review
- Document viewer
- AI recommendations panel
- Confidence scores
- Approve/Reject actions

### 5. HQ Analytics
- KPI cards
- Charts and graphs
- Export functionality
- AI insights

## Flutter Packages Needed

```yaml
dependencies:
  # UI Components
  flutter_svg: ^2.0.9
  google_fonts: ^6.1.0
  
  # Icons
  lucide_icons: ^0.1.0  # Similar to lucide-react
  
  # Animations
  flutter_animate: ^4.3.0
  
  # Charts
  fl_chart: ^0.65.0  # Already installed
  
  # File Upload
  file_picker: ^6.1.1  # Already installed
  image_picker: ^1.0.5  # Already installed
  
  # Existing packages
  dio: ^5.4.0
  riverpod: ^2.4.9
  go_router: ^13.0.0
```

## Implementation Steps

### Phase 1: Design System Setup
1. Create color constants matching Figma
2. Create text styles
3. Create reusable widgets (cards, buttons, badges)
4. Set up theme configuration

### Phase 2: Login Page
1. Create gradient background
2. Implement role tabs
3. Style input fields
4. Add animations

### Phase 3: Agency Dashboard
1. Create sidebar navigation
2. Implement stats cards
3. Build request list
4. Add search and filters

### Phase 4: Other Pages
1. Upload page with file pickers
2. ASM review page
3. HQ analytics page

## Key Differences from Current Flutter App

### Current
- Simple Material Design
- Basic login page
- Minimal styling
- No animations

### New (Figma-based)
- Modern shadcn-inspired design
- Role-based login tabs
- Rich animations
- Gradient backgrounds
- Status badges with colors
- Icon-rich interface
- Card-based layouts

## Next Steps

1. Update `lib/core/theme/app_theme.dart` with new colors
2. Create `lib/core/theme/app_text_styles.dart`
3. Create reusable widgets in `lib/core/widgets/`
4. Rebuild login page
5. Rebuild dashboard pages

## Timeline Estimate

- Design System Setup: 30 minutes
- Login Page: 45 minutes
- Agency Dashboard: 1 hour
- Upload Page: 1 hour
- ASM Review: 1 hour
- HQ Analytics: 1 hour

**Total**: ~5 hours for complete UI redesign

## Benefits

✅ Modern, professional UI
✅ Consistent with Figma design
✅ Better user experience
✅ Animated interactions
✅ Role-specific interfaces
✅ Mobile-responsive
✅ Maintains Flutter performance
