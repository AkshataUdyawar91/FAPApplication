/// Detects user intent from natural language typed input in the assistant chat.
class ChatIntentDetector {
  ChatIntentDetector._();

  /// Patterns that indicate the user wants to create a new submission.
  static const _createRequestPatterns = [
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
    'new request',
    'apply for approval',
    'open a ticket',
    'open ticket',
    'new submission',
    'make a request',
    'make request',
    'file a request',
    'file request',
    'i want to submit',
    'i want to create',
    'i want to raise',
    'i want to start',
  ];

  /// Patterns that indicate the user wants help / capability list.
  static const _helpPatterns = [
    'help',
    'how',
    'process',
    'what can you do',
    'what do you do',
  ];

  /// Detects intent from typed input. Priority: createRequest > help > unknown.
  static ChatIntent detect(String input) {
    final normalized = input.toLowerCase().trim();

    for (final pattern in _createRequestPatterns) {
      if (normalized.contains(pattern)) return ChatIntent.createRequest;
    }

    for (final pattern in _helpPatterns) {
      if (normalized.contains(pattern)) return ChatIntent.help;
    }

    return ChatIntent.unknown;
  }
}

enum ChatIntent {
  createRequest,
  help,
  unknown,
}
