import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import '../../../../core/constants/api_constants.dart';

/// Callback types for SignalR push events.
typedef ExtractionCompleteCallback = void Function(
    Map<String, dynamic> payload,);
typedef ValidationCompleteCallback = void Function(
    Map<String, dynamic> payload,);
typedef SubmissionStatusChangedCallback = void Function(
    Map<String, dynamic> payload,);

/// Manages the SignalR connection lifecycle for real-time
/// submission notifications.
abstract class SignalRDataSource {
  /// Starts the SignalR connection with the given auth token.
  Future<void> connect(String authToken);

  /// Stops the SignalR connection.
  Future<void> disconnect();

  /// Joins a submission-specific group to receive updates.
  Future<void> joinSubmission(String submissionId);

  /// Leaves a submission-specific group.
  Future<void> leaveSubmission(String submissionId);

  /// Registers a callback for ExtractionComplete events.
  void onExtractionComplete(ExtractionCompleteCallback callback);

  /// Registers a callback for ValidationComplete events.
  void onValidationComplete(ValidationCompleteCallback callback);

  /// Registers a callback for SubmissionStatusChanged events.
  void onSubmissionStatusChanged(
      SubmissionStatusChangedCallback callback,);

  /// Whether the connection is currently active.
  bool get isConnected;
}

class SignalRDataSourceImpl implements SignalRDataSource {
  HubConnection? _hubConnection;
  bool _connected = false;

  ExtractionCompleteCallback? _onExtractionComplete;
  ValidationCompleteCallback? _onValidationComplete;
  SubmissionStatusChangedCallback? _onSubmissionStatusChanged;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(String authToken) async {
    final hubUrl = ApiConstants.signalRHubUrl;

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => authToken,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _registerEventHandlers();

    await _hubConnection!.start();
    _connected = true;
  }

  void _registerEventHandlers() {
    _hubConnection!.on('ExtractionComplete', (arguments) {
      if (_onExtractionComplete != null && arguments != null && arguments.isNotEmpty) {
        _onExtractionComplete!(
            Map<String, dynamic>.from(arguments[0] as Map),);
      }
    });

    _hubConnection!.on('ValidationComplete', (arguments) {
      if (_onValidationComplete != null && arguments != null && arguments.isNotEmpty) {
        _onValidationComplete!(
            Map<String, dynamic>.from(arguments[0] as Map),);
      }
    });

    _hubConnection!.on('SubmissionStatusChanged', (arguments) {
      if (_onSubmissionStatusChanged != null && arguments != null && arguments.isNotEmpty) {
        _onSubmissionStatusChanged!(
            Map<String, dynamic>.from(arguments[0] as Map),);
      }
    });
  }

  @override
  Future<void> disconnect() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _connected = false;
      _hubConnection = null;
    }
  }

  @override
  Future<void> joinSubmission(String submissionId) async {
    if (_hubConnection != null && _connected) {
      await _hubConnection!
          .invoke('JoinSubmission', args: [submissionId]);
    }
  }

  @override
  Future<void> leaveSubmission(String submissionId) async {
    if (_hubConnection != null && _connected) {
      await _hubConnection!
          .invoke('LeaveSubmission', args: [submissionId]);
    }
  }

  @override
  void onExtractionComplete(ExtractionCompleteCallback callback) {
    _onExtractionComplete = callback;
  }

  @override
  void onValidationComplete(ValidationCompleteCallback callback) {
    _onValidationComplete = callback;
  }

  @override
  void onSubmissionStatusChanged(
      SubmissionStatusChangedCallback callback,) {
    _onSubmissionStatusChanged = callback;
  }
}
