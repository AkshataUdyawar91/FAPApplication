import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/signalr_datasource.dart';
import 'conversation_notifier.dart';

/// Connection state for the SignalR hub.
enum SignalRConnectionStatus { disconnected, connecting, connected, error }

/// State for the SignalR notifier.
class SignalRState extends Equatable {
  final SignalRConnectionStatus status;
  final String? currentSubmissionId;
  final String? error;

  const SignalRState({
    this.status = SignalRConnectionStatus.disconnected,
    this.currentSubmissionId,
    this.error,
  });

  SignalRState copyWith({
    SignalRConnectionStatus? status,
    String? currentSubmissionId,
    String? error,
  }) {
    return SignalRState(
      status: status ?? this.status,
      currentSubmissionId: currentSubmissionId ?? this.currentSubmissionId,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, currentSubmissionId, error];
}

/// Manages SignalR connection lifecycle and dispatches push events
/// to the [ConversationNotifier].
class SignalRNotifier extends StateNotifier<SignalRState> {
  final SignalRDataSource _dataSource;
  final ConversationNotifier _conversationNotifier;

  SignalRNotifier(this._dataSource, this._conversationNotifier)
      : super(const SignalRState());

  /// Connects to the SignalR hub and registers event handlers.
  Future<void> connect(String authToken) async {
    if (state.status == SignalRConnectionStatus.connected) return;

    state = state.copyWith(
      status: SignalRConnectionStatus.connecting,
      error: null,
    );

    try {
      // Register event handlers before connecting
      _dataSource.onExtractionComplete((payload) {
        _conversationNotifier.handlePushEvent('ExtractionComplete', payload);
      });

      _dataSource.onValidationComplete((payload) {
        _conversationNotifier.handlePushEvent('ValidationComplete', payload);
      });

      _dataSource.onSubmissionStatusChanged((payload) {
        _conversationNotifier.handlePushEvent(
          'SubmissionStatusChanged',
          payload,
        );
      });

      await _dataSource.connect(authToken);
      state = state.copyWith(status: SignalRConnectionStatus.connected);
    } catch (e) {
      state = state.copyWith(
        status: SignalRConnectionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Joins a submission group to receive real-time updates.
  Future<void> joinSubmission(String submissionId) async {
    if (state.status != SignalRConnectionStatus.connected) return;

    // Leave previous group if any
    if (state.currentSubmissionId != null) {
      await _dataSource.leaveSubmission(state.currentSubmissionId!);
    }

    await _dataSource.joinSubmission(submissionId);
    state = state.copyWith(currentSubmissionId: submissionId);
  }

  /// Leaves the current submission group.
  Future<void> leaveSubmission() async {
    if (state.currentSubmissionId == null) return;

    if (state.status == SignalRConnectionStatus.connected) {
      await _dataSource.leaveSubmission(state.currentSubmissionId!);
    }
    state = SignalRState(
      status: state.status,
    );
  }

  /// Disconnects from the SignalR hub.
  Future<void> disconnect() async {
    if (state.currentSubmissionId != null) {
      await leaveSubmission();
    }
    await _dataSource.disconnect();
    state = const SignalRState();
  }

  @override
  void dispose() {
    _dataSource.disconnect();
    super.dispose();
  }
}
