# Requirements: CH Teams Bot — New Claim Notification

## Overview
The CH (Circle Head / ASM) needs to receive a rich Microsoft Teams notification the moment a new claim submission completes AI validation and is assigned to them. The notification must provide enough context for quick decision-making directly within Teams, with fallback to email when Teams is unavailable.

## Personas
- **CH (Circle Head)**: First-level approver, manages 5–15 dealers across a territory. Receives 3–8 submissions/week (up to 15–20 at quarter-end). Primary workspace is Microsoft Teams on mobile.
- **Agency**: Submits document packages (PO, invoices, photos, cost summaries). Receives status updates after CH action.
- **RA (Regional Approver / HQ)**: Second-level approver. Receives submissions forwarded by CH after approval.

> **Codebase Mapping**: CH = ASM role, RA = HQ role, ReadyForReview = PendingASM state, AIProcessing = Extracting/Validating states.

---

## User Stories

### Requirement 1: Notification Trigger on Submission Ready for Review

**User Story**: As a CH, I want to automatically receive a Teams notification when a submission completes AI validation and is assigned to me, so that I am immediately aware of new claims requiring my attention.

**Acceptance Criteria**:

- 1.1 Given a submission's status transitions to PendingASM (ReadyForReview) AND the submission is assigned to a CH AND the CH has a valid `TeamsConversationRef` stored in the Users table, When the state transition completes, Then a Teams Adaptive Card notification is sent to the CH's 1:1 chat with the ClaimsIQ bot within 2 minutes.
- 1.2 Given a submission is still in Extracting or Validating state (AI pipeline incomplete), When the pipeline is running, Then NO notification is sent until the pipeline completes and status reaches PendingASM.
- 1.3 Given a CH user record has `TeamsConversationRef` = NULL (bot not installed), When a submission reaches PendingASM, Then the system falls back to email notification (see Requirement 7) and does NOT attempt Teams delivery.
- 1.4 Given a submission is in Draft state (agency has not submitted), When the draft exists, Then NO notification is sent to any CH.
- 1.5 Given the AI validation pipeline fails and the submission status remains at Extracting or Validating, When the pipeline errors out, Then NO notification is sent to the CH (no partial notifications). A separate ops alert is triggered.

---

### Requirement 2: Adaptive Card — Header and Key Facts Sections

**User Story**: As a CH, I want the notification card to show a clear header and key claim facts at a glance, so that I can quickly identify which submission this is about without opening the portal.

**Acceptance Criteria**:

- 2.1 Given a new claim notification is sent, When the Adaptive Card renders, Then Section 1 (Header) displays the title "New Claim Submitted" (size=medium, weight=bolder, color=accent) and the notification timestamp (size=small, isSubtle=true, right-aligned).
- 2.2 Given a new claim notification is sent, When the Adaptive Card renders, Then Section 2 (Key Facts) displays a FactSet with: Agency name, PO Number, Invoice Number, Invoice Amount (formatted with ₹ currency), State, Submitted timestamp, Team count with photo count (e.g., "3 teams | 19 photos"), and Inquiry count with completion (e.g., "87 records (84 complete)").
- 2.3 Given the card is viewed on Teams mobile (Android or iOS), When the FactSet renders, Then all facts are readable without horizontal scrolling and labels/values wrap cleanly.
- 2.4 Given any token value is missing or null in the source data, When the card is populated, Then the token displays a sensible fallback (e.g., "N/A" or "—") and never shows raw `{{placeholder}}` text.

---

### Requirement 3: Adaptive Card — AI Recommendation Section

**User Story**: As a CH, I want to see the AI's recommendation prominently color-coded on the notification card, so that I can instantly assess whether this claim is safe to approve, needs review, or has significant issues.

**Acceptance Criteria**:

- 3.1 Given a submission with confidence score ≥ 80, When the card renders, Then the AI section container uses style="good" (green tint), displays "APPROVE" as the recommendation, and shows the passed/total checks count.
- 3.2 Given a submission with confidence score 60–79, When the card renders, Then the AI section container uses style="attention" (amber tint) and displays "REVIEW" as the recommendation.
- 3.3 Given a submission with confidence score < 60, When the card renders, Then the AI section container uses style="warning" (red tint) and displays "REJECT" as the recommendation.
- 3.4 Given a submission has validation failures or warnings, When the card renders, Then the AI section displays the top 3 issues sorted by severity (failures first, then warnings), extracted from ValidationResults where Status = 'Fail' or 'Warning'.
- 3.5 Given a submission has zero validation failures and zero warnings, When the card renders, Then the AI section displays "All checks passed."
- 3.6 Given a submission has more than 3 validation issues, When the card renders, Then the card shows the top 3 issues followed by "... and N more issues" with a "[View all N issues]" link/text.

---

### Requirement 4: Adaptive Card — PO Balance Quick Glance Section

**User Story**: As a CH, I want to see the PO balance breakdown directly on the notification card, so that I can verify the claim amount is within the PO budget without performing a separate lookup.

**Acceptance Criteria**:

- 4.1 Given a submission notification is sent, When the card renders, Then the PO Balance section displays: PO Total Amount, Previously Consumed amount, This Claim amount, and Remaining After Approval amount, all formatted with ₹ currency.
- 4.2 Given the claim amount is within the remaining PO balance, When the card renders, Then a "✅ Within PO balance" status indicator is shown.
- 4.3 Given the claim amount exceeds the remaining PO balance, When the card renders, Then a "⚠️ Exceeds PO balance by ₹X" status indicator is shown (red/warning styling).
- 4.4 Given the PO balance data has a "balance as of" timestamp, When the card renders, Then the timestamp is displayed (e.g., "Balance as of 12-Mar-2026, 08:00 AM").
- 4.5 Given the PO balance data is older than 6 hours, When the card renders, Then a "[Refresh PO Balance]" button is shown that triggers a real-time balance refresh via integration.
- 4.6 Given the PO balance arithmetic, When calculated, Then Remaining After Approval = (PO Total Amount - Previously Consumed) - This Claim Amount, and this arithmetic is always correct.

---

### Requirement 5: Adaptive Card — Action Buttons with Conditional Visibility

**User Story**: As a CH, I want contextually appropriate action buttons on the notification card, so that I can take the right action based on the AI recommendation without unnecessary steps.

**Acceptance Criteria**:

- 5.1 Given a submission with AI recommendation = APPROVE (score ≥ 80), When the card renders, Then three buttons are shown: "Quick Approve" (primary/accent style), "Review Details", and "Open in Portal".
- 5.2 Given a submission with AI recommendation = REVIEW (score 60–79), When the card renders, Then two buttons are shown: "Review Details" (primary style) and "Open in Portal". The "Quick Approve" button is hidden.
- 5.3 Given a submission with AI recommendation = REJECT (score < 60), When the card renders, Then two buttons are shown: "Review Details" (primary style) and "Open in Portal". The "Quick Approve" button is hidden.
- 5.4 Given the "Quick Approve" button, When implemented, Then it uses Action.Submit with data `{ action: 'quick_approve', submissionId }` so the bot handles it inline.
- 5.5 Given the "Review Details" button, When implemented, Then it uses Action.Submit with data `{ action: 'review_details', submissionId }` so the bot posts a follow-up validation breakdown.
- 5.6 Given the "Open in Portal" button, When implemented, Then it uses Action.OpenUrl with the deep link URL `https://claimsiq.bajaj.com/review/{submissionId}`.

---

### Requirement 6: Quick Approve Inline Flow

**User Story**: As a CH, I want to approve a clean submission directly within Teams in 4 or fewer interaction steps, so that I don't have to switch to the portal for straightforward approvals.

**Acceptance Criteria**:

- 6.1 Given the CH clicks "Quick Approve" on the notification card, When the bot receives the Action.Submit, Then the bot posts a confirmation message: "You're about to approve CIQ-{number} ({agencyName}, ₹{amount}). Do you want to continue? [Approve Invoice] [Cancel]".
- 6.2 Given the CH clicks "Approve Invoice" on the confirmation, When confirmed, Then the bot asks for optional comments: "Any comments? (optional — type or tap Skip) [Skip]".
- 6.3 Given the CH provides comments or clicks "Skip", When the response is received, Then the bot calls `POST /api/submissions/{id}/asm-approve` with `{ comments, channel: 'TeamsBot' }` and posts a success message: "✅ Approved! CIQ-{number} forwarded to Finance (RA). {agencyName} will be notified. Payable amount: ₹{amount}".
- 6.4 Given the CH clicks "Cancel" on the confirmation, When cancelled, Then the bot posts "Approval cancelled. No changes made." and the submission remains in PendingASM state.
- 6.5 Given the entire Quick Approve flow, When counted, Then the flow completes in ≤ 4 interaction steps: card → confirmation → comments → confirmed.
- 6.6 Given the approval succeeds, When the backend processes it, Then the following are triggered: RA (HQ) notification, Agency status update notification, in-app notification, and audit log entry in RequestApprovalHistory.

---

### Requirement 7: Email Fallback Notification

**User Story**: As a CH who has not installed the ClaimsIQ Teams bot, I want to receive an email notification when a new claim is assigned to me, so that I am still informed even without Teams integration.

**Acceptance Criteria**:

- 7.1 Given a CH user has `TeamsConversationRef` = NULL in the Users table, When a submission reaches PendingASM assigned to that CH, Then an email notification is sent within 2 minutes.
- 7.2 Given the email notification, When sent, Then the subject line is "ClaimsIQ: New claim from {agencyName} — ₹{invoiceAmount}".
- 7.3 Given the email notification, When rendered, Then the body contains: ClaimsIQ logo header, the same 8 key facts as the adaptive card (HTML table format), AI recommendation section (color-coded inline), PO balance section, and a CTA button "Review in ClaimsIQ Portal" linking to the portal URL.
- 7.4 Given the email notification, When the CH reads it, Then the email does NOT support inline approval — the CH must click through to the portal to take action.
- 7.5 Given the email is sent, When recorded, Then a row is created in the Notifications table with `Channel = 'Email'`.
- 7.6 Given the email template, When stored, Then it is located at `/templates/email/new-submission.html` and uses the same data context as the adaptive card.
- 7.7 Given the email footer, When rendered, Then it includes: "You're receiving this because you're the assigned CH. Install the ClaimsIQ Teams bot for richer notifications."

---

### Requirement 8: Bot Installation and Conversation Reference Capture

**User Story**: As a CH, I want the ClaimsIQ bot to automatically capture my Teams conversation reference when I first interact with it, so that the system can send me proactive notifications going forward.

**Acceptance Criteria**:

- 8.1 Given a CH sends any message to the ClaimsIQ bot for the first time, When the bot receives the message, Then the bot captures the ConversationReference via `turnContext.Activity.GetConversationReference()` and stores it as JSON in `Users.TeamsConversationRef` and extracts the channel ID into `Users.TeamsChannelId`.
- 8.2 Given the bot is registered in Azure Bot Service, When the Teams App Manifest is created, Then the bot is configured in "personal" scope (1:1 chat with user).
- 8.3 Given the Teams app is published, When deployed, Then it is side-loaded via Bajaj's Teams admin center for all CH and RA users.
- 8.4 Given a CH reinstalls Teams or the conversation reference becomes stale, When the bot attempts proactive messaging and receives a 403/404 error, Then the system sets `TeamsConversationRef = NULL` and falls back to email. On the CH's next interaction with the bot, the reference is re-captured.

---

### Requirement 9: Proactive Messaging Infrastructure

**User Story**: As the system, I want to send Teams notifications proactively (without the CH initiating a conversation), so that CHs receive timely claim notifications as soon as submissions are ready for review.

**Acceptance Criteria**:

- 9.1 Given a submission reaches PendingASM, When the Notification Dispatcher processes the event, Then it loads the CH's ConversationReference from `Users.TeamsConversationRef`, populates the adaptive card template with submission data, and sends the card via `BotAdapter.ContinueConversationAsync`.
- 9.2 Given the proactive message send, When executed, Then it uses the Bot App ID from Azure Bot registration, the stored ConversationReference, and a callback that constructs and sends the Adaptive Card attachment.
- 9.3 Given multiple submissions arrive for the same CH within a short window, When sending notifications, Then cards are sent sequentially with a 2-second delay between them to avoid Teams API rate limiting.
- 9.4 Given the Teams API returns an error (503, timeout), When the send fails, Then the system retries 3 times with exponential backoff (5s, 15s, 45s). After 3 failures, it falls back to email and logs all attempts in the Notifications table with `RetryCount` and `Status = 'Failed'`.
- 9.5 Given the Notification Dispatcher, When assembling card data, Then it calls `NotificationDataService.GetSubmissionCardDataAsync(submissionId)` which returns a strongly-typed DTO with all token values.

---

### Requirement 10: Adaptive Card Template and Token Population

**User Story**: As a developer, I want the adaptive card to be built from a JSON template with token placeholders populated at send time, so that the card design can be updated independently of the code.

**Acceptance Criteria**:

- 10.1 Given the card template, When stored, Then it is located at `/templates/teams-cards/new-submission-card.json` and follows Adaptive Card schema version 1.4.
- 10.2 Given the template, When populated, Then the AdaptiveCards.Templating NuGet package is used: `var template = new AdaptiveCardTemplate(jsonTemplate); var cardJson = template.Expand(dataContext);` where dataContext is a C# object with all token values.
- 10.3 Given the token set, When the card is populated, Then ALL of the following tokens are resolved: submissionId, submissionNumber, agencyName, poNumber, invoiceNumber, invoiceAmount, state, submittedAt, teamCount, photoCount, inquiryTotal, inquiryComplete, recommendation, cardStyle, passedChecks, totalChecks, warningsList, poTotalAmount, poRemainingBalance, remainingAfterApproval, poBalanceStatus, balanceAsOf, showQuickApprove, portalUrl.
- 10.4 Given 5 different claim submissions, When cards are generated, Then no raw `{{placeholder}}` tokens are visible in any rendered card.

---

### Requirement 11: Review Details Inline Flow

**User Story**: As a CH, I want to click "Review Details" on the notification card and see a per-document validation breakdown directly in Teams, so that I can review issues without switching to the portal.

**Acceptance Criteria**:

- 11.1 Given the CH clicks "Review Details" on the notification card, When the bot receives the Action.Submit with `{ action: 'review_details', submissionId }`, Then the bot posts a follow-up message containing the full per-document validation summary.
- 11.2 Given the validation summary is posted, When the CH reviews it, Then the CH can approve or reject the submission inline within the Teams conversation (triggering the appropriate approval/rejection flow).
- 11.3 Given the validation summary, When rendered, Then it includes validation results grouped by document type (PO, Invoice, Cost Summary, Photos, Inquiries) with pass/fail status for each check.

---

### Requirement 12: Idempotency and Duplicate Action Prevention

**User Story**: As a CH, I want the system to gracefully handle duplicate button clicks on the notification card, so that accidental double-taps don't create duplicate approvals or errors.

**Acceptance Criteria**:

- 12.1 Given the CH clicks "Quick Approve" on a card, When the bot processes the action, Then it first checks the current submission status. If the status is no longer PendingASM (e.g., already approved), the bot responds: "This submission has already been approved. No further action needed." and does NOT create a duplicate approval.
- 12.2 Given the CH clicks "Quick Approve" twice rapidly, When both requests arrive, Then only one ApprovalActions/RequestApprovalHistory record is created. The second click receives the idempotent response.
- 12.3 Given the CH clicks "Review Details" on an already-processed submission, When the bot receives the action, Then the bot still shows the validation summary (read-only) but indicates the current status (e.g., "This submission was approved on {date}").

---

### Requirement 13: Cross-Platform Card Rendering

**User Story**: As a CH, I want the notification card to render correctly on all Teams platforms, so that I can act on claims regardless of which device I'm using.

**Acceptance Criteria**:

- 13.1 Given the Adaptive Card, When rendered on Teams Desktop (Windows/Mac), Then all 5 sections display correctly with no truncation, and all buttons are functional.
- 13.2 Given the Adaptive Card, When rendered on Teams Web, Then all 5 sections display correctly with no truncation, and all buttons are functional.
- 13.3 Given the Adaptive Card, When rendered on Teams Mobile (iOS), Then all sections are readable without horizontal scrolling, FactSet wraps cleanly, and buttons are tappable with minimum 48×48 touch targets.
- 13.4 Given the Adaptive Card, When rendered on Teams Mobile (Android), Then all sections are readable without horizontal scrolling, FactSet wraps cleanly, and buttons are tappable with minimum 48×48 touch targets.
- 13.5 Given the card payload, When generated, Then it is lightweight (~2KB JSON) with no embedded images (use emojis for status indicators) to ensure fast rendering on slow mobile connections.

---

### Requirement 14: Error Handling and Resilience

**User Story**: As the system, I want robust error handling for all notification delivery paths, so that CHs always receive their notifications through at least one channel.

**Acceptance Criteria**:

- 14.1 Given the Teams API returns a 403 or 404 error during proactive messaging, When the error is caught, Then the system sets `Users.TeamsConversationRef = NULL`, falls back to email notification, and logs the error.
- 14.2 Given the Teams API returns a 503 or timeout, When the error is caught, Then the system retries 3 times with exponential backoff (5s, 15s, 45s). After 3 failures, it falls back to email.
- 14.3 Given all retry attempts fail, When the final failure occurs, Then the Notifications table records `RetryCount = 3`, `Status = 'Failed'`, and a new row is created with `Channel = 'Email'` for the fallback.
- 14.4 Given a CH has been reassigned due to territory change between submission time and pipeline completion, When the notification fires, Then it goes to the `AssignedCHUserId` that was set at submit time (not the new territory mapping).
- 14.5 Given the validation pipeline takes longer than 5 minutes, When the pipeline eventually completes, Then the notification is sent with complete data (delayed but not partial). No notification fires while the pipeline is still running.

---

### Requirement 15: Notification Logging and Audit Trail

**User Story**: As an administrator, I want all notification attempts and outcomes logged, so that I can troubleshoot delivery issues and audit the notification history.

**Acceptance Criteria**:

- 15.1 Given any notification is sent (Teams or email), When delivered, Then a record is created in the Notifications table with: Channel ('Teams' or 'Email'), Status ('Sent', 'Failed', 'Pending'), RetryCount, SentAt timestamp, and the related SubmissionId.
- 15.2 Given a Teams notification fails and falls back to email, When both attempts are recorded, Then the Notifications table contains two rows: one for the failed Teams attempt and one for the email fallback.
- 15.3 Given a Quick Approve action is taken via Teams, When the approval is processed, Then the RequestApprovalHistory record includes `Channel = 'TeamsBot'` to distinguish it from portal-based approvals.
