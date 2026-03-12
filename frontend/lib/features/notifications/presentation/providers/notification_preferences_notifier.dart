import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_preference_model.dart';
import '../../domain/repositories/notification_repository.dart';

/// State for notification preferences
class NotificationPreferencesState extends Equatable {
  final List<NotificationTypePreference> preferences;
  final bool isLoading;
  final String? error;

  const NotificationPreferencesState({
    this.preferences = const [],
    this.isLoading = false,
    this.error,
  });

  NotificationPreferencesState copyWith({
    List<NotificationTypePreference>? preferences,
    bool? isLoading,
    String? error,
  }) {
    return NotificationPreferencesState(
      preferences: preferences ?? this.preferences,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [preferences, isLoading, error];
}

/// Notifier for managing notification preferences
class NotificationPreferencesNotifier
    extends StateNotifier<NotificationPreferencesState> {
  final NotificationRepository repository;

  NotificationPreferencesNotifier({required this.repository})
      : super(const NotificationPreferencesState());

  /// Fetch preferences from the API
  Future<void> loadPreferences() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await repository.getPreferences();

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (response) {
        state = state.copyWith(
          isLoading: false,
          preferences: response.preferences,
        );
      },
    );
  }

  /// Update a single preference toggle
  Future<void> updatePreference(
    String notificationType, {
    bool? isPushEnabled,
    bool? isEmailEnabled,
  }) async {
    // Find the current preference
    final index = state.preferences
        .indexWhere((p) => p.notificationType == notificationType);
    if (index == -1) return;

    final current = state.preferences[index];
    final newPush = isPushEnabled ?? current.isPushEnabled;
    final newEmail = isEmailEnabled ?? current.isEmailEnabled;

    // Optimistic update
    final updated = current.copyWith(
      isPushEnabled: newPush,
      isEmailEnabled: newEmail,
    );
    final updatedList = List<NotificationTypePreference>.from(state.preferences);
    updatedList[index] = updated;
    state = state.copyWith(preferences: updatedList);

    // Call API
    final result = await repository.updatePreference(
      notificationType,
      newPush,
      newEmail,
    );

    result.fold(
      (failure) {
        // Revert on failure
        final revertedList =
            List<NotificationTypePreference>.from(state.preferences);
        revertedList[index] = current;
        state = state.copyWith(
          preferences: revertedList,
          error: failure.message,
        );
      },
      (_) {
        // Success — optimistic update already applied
      },
    );
  }
}
