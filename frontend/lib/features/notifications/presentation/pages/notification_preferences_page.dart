import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/push_notification_providers.dart';

/// Page for managing notification preferences.
/// Displays toggle switches for push and email per notification type.
class NotificationPreferencesPage extends ConsumerStatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  ConsumerState<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends ConsumerState<NotificationPreferencesPage> {
  @override
  void initState() {
    super.initState();
    // Fetch preferences on page load
    Future.microtask(() {
      ref.read(notificationPreferencesProvider.notifier).loadPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefsState = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: _buildBody(prefsState),
    );
  }

  Widget _buildBody(prefsState) {
    if (prefsState.isLoading) {
      return _buildLoadingShimmer();
    }

    if (prefsState.error != null && prefsState.preferences.isEmpty) {
      return _buildErrorState(prefsState.error!);
    }

    if (prefsState.preferences.isEmpty) {
      return const Center(
        child: Text(
          'No notification preferences available.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(notificationPreferencesProvider.notifier)
          .loadPreferences(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: prefsState.preferences.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final pref = prefsState.preferences[index];
          return _buildPreferenceCard(pref);
        },
      ),
    );
  }

  Widget _buildPreferenceCard(pref) {
    final displayName = _formatNotificationType(pref.notificationType);

    return Card(
      color: AppColors.cardBackground,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildToggleRow(
              label: 'Push Notifications',
              value: pref.isPushEnabled,
              onChanged: (value) {
                ref
                    .read(notificationPreferencesProvider.notifier)
                    .updatePreference(
                      pref.notificationType,
                      isPushEnabled: value,
                    );
              },
            ),
            const Divider(color: AppColors.borderLight, height: 16),
            _buildToggleRow(
              label: 'Email Notifications',
              value: pref.isEmailEnabled,
              onChanged: (value) {
                ref
                    .read(notificationPreferencesProvider.notifier)
                    .updatePreference(
                      pref.notificationType,
                      isEmailEnabled: value,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.borderLight,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.rejectedText,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load preferences',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(notificationPreferencesProvider.notifier)
                  .loadPreferences(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Convert camelCase notification type to human-readable label
  String _formatNotificationType(String type) {
    return type
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim();
  }
}
