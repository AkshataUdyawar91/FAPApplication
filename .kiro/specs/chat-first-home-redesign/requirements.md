# Requirements Document

## Introduction

Redesign the home page for all user roles (Agency, ASM, HQ/RA) to adopt a chat-first, minimalist layout. The conversational AI chat becomes the primary interface element, supplemented by 1–2 role-specific KPI cards and 1–2 quick action buttons. The chat answers questions and navigates users to application sections. The current cluttered dashboard pages (stats cards, filters, document tables) are replaced with a clean, focused experience. The existing detailed views (document lists, review queues, analytics) remain accessible via navigation and chat commands. Bajaj brand colors (#003087 Dark Blue, #00A3E0 Light Blue) are applied consistently. The layout is responsive across web and mobile.

## Glossary

- **Home_Page**: The primary landing page displayed after login for each user role, containing the Chat_Panel, KPI_Strip, and Quick_Actions
- **Chat_Panel**: The central conversational AI widget occupying the majority of the Home_Page viewport, accepting natural language input and returning answers or navigation actions
- **KPI_Strip**: A compact row (desktop/tablet) or stacked column (mobile) of 1–2 role-specific key performance indicator cards displayed above or beside the Chat_Panel
- **Quick_Actions**: 1–2 prominent action buttons relevant to the user's role, displayed near the KPI_Strip
- **Navigation_Command**: A user message in the Chat_Panel that the system interprets as an intent to navigate to a specific application section (e.g., "Show pending approvals", "Go to upload")
- **Agency_User**: A user with the Agency role who submits document packages
- **ASM_User**: A user with the Area Sales Manager role who reviews and approves/rejects submissions at the first level
- **HQ_RA_User**: A user with the HQ/RA (Headquarters/Regional Authority) role who performs second-level review and accesses analytics
- **Bajaj_Brand_Theme**: The visual identity system using primary color #003087 (Dark Blue), secondary color #00A3E0 (Light Blue), and background #FFFFFF (White)
- **Device_Type**: The responsive classification of the viewport: mobile (<600px), tablet (600–1024px), or desktop (>1024px)

## Requirements

### Requirement 1: Chat-First Home Page Layout

**User Story:** As a user of any role, I want the home page to center around a conversational chat interface with minimal surrounding elements, so that I can interact with the system naturally without visual clutter.

#### Acceptance Criteria

1. WHEN a user logs in and lands on the Home_Page, THE Home_Page SHALL display the Chat_Panel as the primary element occupying at least 60% of the available viewport height on desktop and tablet, and at least 50% on mobile
2. THE Home_Page SHALL display the KPI_Strip containing exactly 2 KPI cards for the authenticated user's role
3. THE Home_Page SHALL display the Quick_Actions containing exactly 2 action buttons for the authenticated user's role
4. THE Home_Page SHALL NOT display document tables, filter panels, or search bars on the initial view
5. WHILE the Device_Type is desktop or tablet, THE Home_Page SHALL arrange the KPI_Strip and Quick_Actions above the Chat_Panel in a single horizontal row
6. WHILE the Device_Type is mobile, THE Home_Page SHALL stack the KPI_Strip and Quick_Actions vertically above the Chat_Panel

### Requirement 2: Agency Home Page Content

**User Story:** As an Agency_User, I want to see my pending submission count and latest PO status at a glance with quick access to create a new FAP or view my POs, so that I can stay informed and act quickly.

#### Acceptance Criteria

1. WHEN an Agency_User lands on the Home_Page, THE KPI_Strip SHALL display a "Pending Submissions" card showing the count of submissions in uploaded, extracting, or validating states
2. WHEN an Agency_User lands on the Home_Page, THE KPI_Strip SHALL display a "Latest PO Status" card showing the FAP number and current state of the most recently created submission
3. WHEN an Agency_User lands on the Home_Page, THE Quick_Actions SHALL display a "New FAP" button that navigates to the document upload page
4. WHEN an Agency_User lands on the Home_Page, THE Quick_Actions SHALL display a "View POs" button that navigates to the full submissions list view
5. IF the Agency_User has zero submissions, THEN THE "Latest PO Status" KPI card SHALL display "No submissions yet" with a prompt to create one

### Requirement 3: ASM Home Page Content

**User Story:** As an ASM_User, I want to see my pending approval count and quarterly FAP report summary with quick access to the pending review queue, so that I can prioritize my review workload.

#### Acceptance Criteria

1. WHEN an ASM_User lands on the Home_Page, THE KPI_Strip SHALL display a "Pending Approvals" card showing the count of submissions in pendingASMApproval or rejectedByHQ states
2. WHEN an ASM_User lands on the Home_Page, THE KPI_Strip SHALL display a "Quarterly FAP" card showing the total FAP amount for the current quarter formatted in Indian currency notation
3. WHEN an ASM_User lands on the Home_Page, THE Quick_Actions SHALL display a "Pending Queue" button that navigates to the ASM review list filtered to pending submissions
4. WHEN an ASM_User lands on the Home_Page, THE Quick_Actions SHALL display a "Quarterly Report" button that navigates to the quarterly analytics view

### Requirement 4: HQ/RA Home Page Content

**User Story:** As an HQ_RA_User, I want to see my pending HQ approval count and quarterly FAP report summary with quick access to the pending review queue, so that I can manage second-level approvals efficiently.

#### Acceptance Criteria

1. WHEN an HQ_RA_User lands on the Home_Page, THE KPI_Strip SHALL display a "Pending HQ Approvals" card showing the count of submissions in pendingHQApproval state
2. WHEN an HQ_RA_User lands on the Home_Page, THE KPI_Strip SHALL display a "Quarterly FAP" card showing the total FAP amount for the current quarter formatted in Indian currency notation
3. WHEN an HQ_RA_User lands on the Home_Page, THE Quick_Actions SHALL display a "Pending Queue" button that navigates to the HQ review list filtered to pending submissions
4. WHEN an HQ_RA_User lands on the Home_Page, THE Quick_Actions SHALL display a "Quarterly Report" button that navigates to the quarterly analytics view

### Requirement 5: Chat Navigation Commands

**User Story:** As a user of any role, I want to type natural language commands in the chat to navigate to application sections, so that I can move through the app without hunting through menus.

#### Acceptance Criteria

1. WHEN a user types a Navigation_Command in the Chat_Panel, THE Chat_Panel SHALL detect the navigation intent and navigate the application to the corresponding section
2. THE Chat_Panel SHALL support navigation to the following sections: submissions list, upload page, review queue, submission detail, analytics dashboard, and notifications
3. WHEN the Chat_Panel navigates the user to a section, THE Chat_Panel SHALL display a confirmation message indicating the destination (e.g., "Navigating to your pending approvals...")
4. IF the Chat_Panel cannot determine a navigation intent from the user message, THEN THE Chat_Panel SHALL treat the message as a conversational query and respond with an answer
5. WHEN a Navigation_Command targets a section the user's role does not have access to, THE Chat_Panel SHALL inform the user that the section is not available for the user's role

### Requirement 6: Chat Panel as Primary Element

**User Story:** As a user, I want the chat panel to be embedded directly in the home page rather than hidden in a side panel or drawer, so that I can start interacting immediately.

#### Acceptance Criteria

1. THE Chat_Panel on the Home_Page SHALL be rendered inline as the main content area, not as a side panel, drawer, or overlay
2. THE Chat_Panel SHALL display a text input field with a send button at the bottom of the chat area
3. THE Chat_Panel SHALL display suggested starter questions relevant to the user's role when no conversation history exists
4. WHEN the Chat_Panel is in an empty state, THE Chat_Panel SHALL display a welcome message including the user's name and a brief description of capabilities
5. THE Chat_Panel SHALL display a loading indicator while waiting for a response from the backend chat service
6. WHEN a user submits a message, THE Chat_Panel SHALL display the user message immediately in the conversation thread before the response arrives

### Requirement 7: Bajaj Brand Theme Application

**User Story:** As a user, I want the interface to reflect Bajaj brand identity consistently, so that the application feels professional and trustworthy.

#### Acceptance Criteria

1. THE Home_Page SHALL use Bajaj_Brand_Theme primary color (#003087) for the Chat_Panel header, primary action buttons, and active navigation elements
2. THE Home_Page SHALL use Bajaj_Brand_Theme secondary color (#00A3E0) for secondary action buttons, links, and accent highlights
3. THE Home_Page SHALL use Bajaj_Brand_Theme background color (#FFFFFF) for the main content area and card backgrounds
4. THE Home_Page SHALL display the official Bajaj logo in the app bar or sidebar header area
5. THE KPI_Strip cards SHALL use the Bajaj_Brand_Theme primary color for icon accents and value text emphasis

### Requirement 8: Responsive Layout

**User Story:** As a user, I want the home page to adapt gracefully to different screen sizes, so that I have a good experience on both desktop browsers and mobile devices.

#### Acceptance Criteria

1. WHILE the Device_Type is desktop (viewport width >1024px), THE Home_Page SHALL display the sidebar navigation, KPI_Strip in a horizontal row, and the Chat_Panel in the remaining content area
2. WHILE the Device_Type is tablet (viewport width 600–1024px), THE Home_Page SHALL display a collapsed sidebar, KPI_Strip in a horizontal row, and the Chat_Panel below
3. WHILE the Device_Type is mobile (viewport width <600px), THE Home_Page SHALL hide the sidebar, display a hamburger menu in the app bar, stack KPI cards and Quick_Actions vertically, and display the Chat_Panel below
4. THE Chat_Panel input field SHALL remain visible and accessible without scrolling on all Device_Types
5. WHILE the Device_Type is mobile, THE Home_Page SHALL support pull-to-refresh to reload KPI data

### Requirement 9: KPI Data Loading and Error Handling

**User Story:** As a user, I want KPI cards to load data reliably and show clear feedback during loading or errors, so that I always understand the current state of my data.

#### Acceptance Criteria

1. WHILE KPI data is loading, THE KPI_Strip SHALL display skeleton placeholder animations in place of KPI values
2. IF KPI data fails to load, THEN THE KPI_Strip SHALL display an error message with a "Retry" button on the affected KPI card
3. WHEN the user taps the "Retry" button on a failed KPI card, THE KPI_Strip SHALL re-fetch the data for that KPI
4. THE Home_Page SHALL load KPI data asynchronously without blocking the rendering of the Chat_Panel
5. THE KPI_Strip SHALL refresh KPI data when the user returns to the Home_Page from another section

### Requirement 10: Visual Feedback and Interaction States

**User Story:** As a user, I want clear visual feedback for all interactive elements, so that I know the system is responding to my actions.

#### Acceptance Criteria

1. WHEN a user hovers over or taps a Quick_Actions button, THE Quick_Actions button SHALL display a visual state change (color shift or elevation change)
2. WHEN a user taps the send button in the Chat_Panel while a message is being sent, THE send button SHALL be disabled and display a loading spinner until the response arrives
3. WHEN a user taps a KPI card, THE KPI card SHALL navigate to the relevant detail view for that metric
4. THE Quick_Actions buttons SHALL have a minimum touch target size of 48x48 logical pixels
5. IF a network request for chat or KPI data takes longer than 10 seconds, THEN THE Home_Page SHALL display a timeout message with a retry option
