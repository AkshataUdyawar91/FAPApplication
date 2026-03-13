import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Data for a single team entry in the summary.
class TeamSummaryData {
  final String teamName;
  final String dealerName;
  final String city;
  final DateTime startDate;
  final DateTime endDate;
  final int workingDays;
  final int photoCount;
  final int photosValidated;
  final int photosFailed;

  const TeamSummaryData({
    required this.teamName,
    required this.dealerName,
    required this.city,
    required this.startDate,
    required this.endDate,
    required this.workingDays,
    this.photoCount = 0,
    this.photosValidated = 0,
    this.photosFailed = 0,
  });

  /// Creates from the Map<String, dynamic> format used by TeamSummaryCardModel.
  factory TeamSummaryData.fromMap(Map<String, dynamic> map) {
    return TeamSummaryData(
      teamName: map['teamName'] as String? ?? 'N/A',
      dealerName: map['dealerName'] as String? ?? 'N/A',
      city: map['city'] as String? ?? '',
      startDate: map['startDate'] is String
          ? DateTime.parse(map['startDate'] as String)
          : DateTime.now(),
      endDate: map['endDate'] is String
          ? DateTime.parse(map['endDate'] as String)
          : DateTime.now(),
      workingDays: map['workingDays'] as int? ?? 0,
      photoCount: map['photoCount'] as int? ?? 0,
      photosValidated: map['photosValidated'] as int? ?? 0,
      photosFailed: map['photosFailed'] as int? ?? 0,
    );
  }
}

/// Team details summary card showing dealer, city, dates, working days,
/// and photo count/status for each team.
class TeamSummaryCard extends StatelessWidget {
  final List<TeamSummaryData> teams;
  final void Function(int teamIndex)? onEditTeam;

  const TeamSummaryCard({
    super.key,
    required this.teams,
    this.onEditTeam,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.groups, size: 22, color: Color(0xFF003087)),
                const SizedBox(width: 8),
                Text(
                  'Team Summary (${teams.length} team${teams.length == 1 ? '' : 's'})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            // Team entries
            ...teams.asMap().entries.map(
                  (entry) => _buildTeamRow(context, entry.key, entry.value),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRow(BuildContext context, int index, TeamSummaryData team) {
    final dateFormat = DateFormat('dd MMM');
    final allPhotosOk = team.photosFailed == 0 && team.photoCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team name + edit
          Row(
            children: [
              Expanded(
                child: Text(
                  team.teamName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (onEditTeam != null)
                InkWell(
                  onTap: () => onEditTeam!(index),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit, size: 16, color: Color(0xFF003087)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Dealer + City
          Row(
            children: [
              Icon(Icons.store, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${team.dealerName}, ${team.city}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Dates + Working days
          Row(
            children: [
              Icon(Icons.date_range, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '${dateFormat.format(team.startDate)} – ${dateFormat.format(team.endDate)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 12),
              Icon(Icons.work_outline, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '${team.workingDays} days',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Photo count + status
          Row(
            children: [
              Icon(Icons.photo_library, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '${team.photoCount} photo${team.photoCount == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              if (team.photoCount > 0) ...[
                const SizedBox(width: 8),
                Icon(
                  allPhotosOk ? Icons.check_circle : Icons.warning_amber,
                  size: 14,
                  color: allPhotosOk ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  allPhotosOk
                      ? 'All validated'
                      : '${team.photosFailed} issue${team.photosFailed == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: allPhotosOk ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
