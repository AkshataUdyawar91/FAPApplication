/// Detects user intent from natural language typed input in the assistant chat.
/// AC 3.1–3.6: Keyword-phase classification with explicit priority order.
/// Priority: greeting > createRequest > rejectionReason > statusCheck > help > fallback
class ChatIntentDetector {
  ChatIntentDetector._();

  // AC 3.5 — GREETING
  static const _greetingPatterns = [
    'hi',
    'hello',
    'good morning',
    'good afternoon',
    'good evening',
    'hey',
  ];

  // AC 3.3 — NEW_SUBMISSION
  static const _createRequestPatterns = [
    'new request',
    'new submission',
    'create a request',
    'create request',
    'start a new request',
    'start new request',
    'start a new submission',
    'start new submission',
    'create a submission',
    'create submission',
    'raise a request',
    'raise request',
    'submit a request',
    'submit request',
    'apply for approval',
    'open a ticket',
    'open ticket',
    'make a request',
    'make request',
    'file a request',
    'file request',
    'i want to submit',
    'i want to create',
    'i want to raise',
    'i want to start',
    'new',
    'submit',
    'create',
    'start',
  ];

  // AC 3.2 — REJECTION_REASON (checked before statusCheck to avoid "rejected" hijack)
  static const _rejectionReasonPatterns = [
    'why was my claim',
    'why was my submission',
    'why rejected',
    'why returned',
    'rejection reason',
    'return reason',
    'why was it',
    'reject',
    'return',
    'why',
    'correct',
  ];

  // AC 3.1 — STATUS_CHECK
  static const _statusCheckPatterns = [
    'status',
    'pending',
    'where is',
    'show my',
    'track',
    'my claim',
    'my request',
    'my submission',
  ];

  // AC 3.4 — HELP
  static const _helpPatterns = [
    'help',
    'how',
    'process',
    'what can you do',
    'what do you do',
  ];

  /// Detects intent from typed input.
  /// Priority: greeting > createRequest > rejectionReason > statusCheck > help > fallback
  static ChatIntent detect(String input) {
    final q = input.toLowerCase().trim();

    // AC 3.5 — exact-word greeting check to avoid false positives
    for (final pattern in _greetingPatterns) {
      if (q == pattern || q.startsWith('$pattern ') || q.startsWith('$pattern,')) {
        return ChatIntent.greeting;
      }
    }

    // AC 3.3 — NEW_SUBMISSION (multi-word phrases first, then single keywords)
    for (final pattern in _createRequestPatterns) {
      if (q.contains(pattern)) return ChatIntent.createRequest;
    }

    // AC 3.2 — REJECTION_REASON (before statusCheck — "rejected" must not hijack this)
    for (final pattern in _rejectionReasonPatterns) {
      if (q.contains(pattern)) return ChatIntent.rejectionReason;
    }

    // AC 3.1 — STATUS_CHECK
    for (final pattern in _statusCheckPatterns) {
      if (q.contains(pattern)) return ChatIntent.statusCheck;
    }

    // AC 3.4 — HELP
    for (final pattern in _helpPatterns) {
      if (q.contains(pattern)) return ChatIntent.help;
    }

    // AC 3.6 — FALLBACK
    return ChatIntent.fallback;
  }
}

enum ChatIntent {
  greeting,
  createRequest,
  rejectionReason,
  statusCheck,
  help,
  fallback,
  // kept for any legacy references
  unknown,
}
