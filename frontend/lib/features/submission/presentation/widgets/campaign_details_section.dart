import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

class CampaignDetailsSection extends StatefulWidget {
  final Function(Map<String, String>) onFieldsChanged;

  const CampaignDetailsSection({
    super.key,
    required this.onFieldsChanged,
  });

  @override
  State<CampaignDetailsSection> createState() => _CampaignDetailsSectionState();
}

class _CampaignDetailsSectionState extends State<CampaignDetailsSection> {
  // List of teams/campaigns
  final List<TeamData> _teams = [];
  
  // Activity Duration fields (for primary campaign)
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _workingDaysController = TextEditingController();
  
  // Dealership Details fields
  final _dealershipNameController = TextEditingController();
  final _fullAddressController = TextEditingController();
  final _gpsLocationController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  
  bool _isCapturingGPS = false;

  @override
  void initState() {
    super.initState();
    _workingDaysController.text = 'Auto-calculated';
    
    // Add listeners for dealership fields
    _dealershipNameController.addListener(_notifyParent);
    _fullAddressController.addListener(_notifyParent);
  }

  void _calculateWorkingDays() {
    if (_startDate != null && _endDate != null) {
      if (_endDate!.isBefore(_startDate!)) {
        _workingDaysController.text = 'Invalid range';
        return;
      }

      int workingDays = 0;
      DateTime current = _startDate!;
      
      while (current.isBefore(_endDate!) || current.isAtSameMomentAs(_endDate!)) {
        if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
          workingDays++;
        }
        current = current.add(const Duration(days: 1));
      }

      _workingDaysController.text = '$workingDays days';
      _notifyParent();
    } else {
      _workingDaysController.text = 'Auto-calculated';
    }
  }

  void _notifyParent() {
    // Serialize teams data
    final teamsJson = _teams.map((t) => t.toJson()).toList();
    
    widget.onFieldsChanged({
      'startDate': _startDateController.text,
      'endDate': _endDateController.text,
      'workingDays': _workingDaysController.text,
      'dealershipName': _dealershipNameController.text,
      'fullAddress': _fullAddressController.text,
      'gpsLocation': _gpsLocationController.text,
      'teams': teamsJson.toString(),
    });
  }
  
  void _addNewTeam() {
    setState(() {
      _teams.add(TeamData(
        id: DateTime.now().millisecondsSinceEpoch,
        teamName: '',
        memberCount: '',
        role: '',
      ),);
    });
    _notifyParent();
  }
  
  void _removeTeam(int id) {
    setState(() {
      _teams.removeWhere((t) => t.id == id);
    });
    _notifyParent();
  }
  
  void _updateTeam(int id, {String? teamName, String? memberCount, String? role}) {
    setState(() {
      final index = _teams.indexWhere((t) => t.id == id);
      if (index != -1) {
        _teams[index] = TeamData(
          id: id,
          teamName: teamName ?? _teams[index].teamName,
          memberCount: memberCount ?? _teams[index].memberCount,
          role: role ?? _teams[index].role,
        );
      }
    });
    _notifyParent();
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }
  
  Future<void> _captureGPSLocation() async {
    setState(() => _isCapturingGPS = true);
    
    try {
      // Simulate GPS capture - in production, use geolocator package
      await Future.delayed(const Duration(seconds: 1));
      
      // For demo purposes, set a placeholder location
      // In production: use Geolocator.getCurrentPosition()
      setState(() {
        _gpsLocationController.text = '18.5204° N, 73.8567° E'; // Pune coordinates as example
      });
      _notifyParent();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS location captured successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture GPS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturingGPS = false);
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _workingDaysController.dispose();
    _dealershipNameController.dispose();
    _fullAddressController.dispose();
    _gpsLocationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Column(
      children: [
        // Activity Duration Card
        _buildActivityDurationCard(isDesktop),
        const SizedBox(height: 16),
        // Dealership Details Card
        _buildDealershipDetailsCard(isDesktop),
        const SizedBox(height: 16),
        // Teams Section
        _buildTeamsSection(isDesktop),
      ],
    );
  }
  
  Widget _buildTeamsSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing teams
        ..._teams.asMap().entries.map((entry) {
          final index = entry.key;
          final team = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildTeamCard(team, index + 1, isDesktop),
          );
        }),
        // Add New Team button
        _buildAddTeamButton(),
      ],
    );
  }
  
  Widget _buildTeamCard(TeamData team, int teamNumber, bool isDesktop) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Team $teamNumber',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeTeam(team.id),
                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  tooltip: 'Remove team',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            isDesktop 
              ? _buildTeamFieldsRow(team)
              : _buildTeamFieldsColumn(team),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTeamFieldsRow(TeamData team) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTeamTextField(
            initialValue: team.teamName,
            label: 'Team Name',
            placeholder: 'Enter team name',
            icon: Icons.badge,
            onChanged: (value) => _updateTeam(team.id, teamName: value),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTeamTextField(
            initialValue: team.memberCount,
            label: 'Member Count',
            placeholder: 'Number of members',
            icon: Icons.people,
            keyboardType: TextInputType.number,
            onChanged: (value) => _updateTeam(team.id, memberCount: value),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTeamTextField(
            initialValue: team.role,
            label: 'Role/Activity',
            placeholder: 'Team role or activity',
            icon: Icons.work,
            onChanged: (value) => _updateTeam(team.id, role: value),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTeamFieldsColumn(TeamData team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeamTextField(
          initialValue: team.teamName,
          label: 'Team Name',
          placeholder: 'Enter team name',
          icon: Icons.badge,
          onChanged: (value) => _updateTeam(team.id, teamName: value),
        ),
        const SizedBox(height: 12),
        _buildTeamTextField(
          initialValue: team.memberCount,
          label: 'Member Count',
          placeholder: 'Number of members',
          icon: Icons.people,
          keyboardType: TextInputType.number,
          onChanged: (value) => _updateTeam(team.id, memberCount: value),
        ),
        const SizedBox(height: 12),
        _buildTeamTextField(
          initialValue: team.role,
          label: 'Role/Activity',
          placeholder: 'Team role or activity',
          icon: Icons.work,
          onChanged: (value) => _updateTeam(team.id, role: value),
        ),
      ],
    );
  }
  
  Widget _buildTeamTextField({
    required String initialValue,
    required String label,
    required String placeholder,
    required IconData icon,
    required Function(String) onChanged,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
  
  Widget _buildAddTeamButton() {
    return InkWell(
      onTap: _addNewTeam,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withOpacity(0.5), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Add New Team',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityDurationCard(bool isDesktop) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Activity Duration',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            isDesktop ? _buildActivityGridLayout() : _buildActivityStackLayout(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDealershipDetailsCard(bool isDesktop) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.store, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Dealership Details',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            isDesktop ? _buildDealershipGridLayout() : _buildDealershipStackLayout(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityGridLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildDateField(
            controller: _startDateController,
            label: 'Start Date',
            placeholder: 'dd-mm-yyyy',
            onDateSelected: (date) {
              setState(() {
                _startDate = date;
                _startDateController.text = _formatDate(date);
                _calculateWorkingDays();
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDateField(
            controller: _endDateController,
            label: 'End Date',
            placeholder: 'dd-mm-yyyy',
            onDateSelected: (date) {
              setState(() {
                _endDate = date;
                _endDateController.text = _formatDate(date);
                _calculateWorkingDays();
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildReadOnlyField(
            controller: _workingDaysController,
            label: 'Working Days',
            icon: Icons.calendar_today,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityStackLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateField(
          controller: _startDateController,
          label: 'Start Date',
          placeholder: 'dd-mm-yyyy',
          onDateSelected: (date) {
            setState(() {
              _startDate = date;
              _startDateController.text = _formatDate(date);
              _calculateWorkingDays();
            });
          },
        ),
        const SizedBox(height: 12),
        _buildDateField(
          controller: _endDateController,
          label: 'End Date',
          placeholder: 'dd-mm-yyyy',
          onDateSelected: (date) {
            setState(() {
              _endDate = date;
              _endDateController.text = _formatDate(date);
              _calculateWorkingDays();
            });
          },
        ),
        const SizedBox(height: 12),
        _buildReadOnlyField(
          controller: _workingDaysController,
          label: 'Working Days',
          icon: Icons.calendar_today,
        ),
      ],
    );
  }
  
  Widget _buildDealershipGridLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _dealershipNameController,
          label: 'Dealership/Dealer Name',
          placeholder: 'Enter dealership name',
          icon: Icons.store,
        ),
        const SizedBox(height: 16),
        _buildTextAreaField(
          controller: _fullAddressController,
          label: 'Full Address',
          placeholder: 'Full address...',
        ),
        const SizedBox(height: 16),
        _buildGPSLocationField(),
      ],
    );
  }
  
  Widget _buildDealershipStackLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _dealershipNameController,
          label: 'Dealership/Dealer Name',
          placeholder: 'Enter dealership name',
          icon: Icons.store,
        ),
        const SizedBox(height: 12),
        _buildTextAreaField(
          controller: _fullAddressController,
          label: 'Full Address',
          placeholder: 'Full address...',
        ),
        const SizedBox(height: 12),
        _buildGPSLocationField(),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required Function(DateTime) onDateSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
            prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(fontSize: 16),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              onDateSelected(date);
            }
          },
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ],
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
  
  Widget _buildTextAreaField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
  
  Widget _buildGPSLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GPS Location',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _gpsLocationController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Click to capture location',
                  hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
                  prefixIcon: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isCapturingGPS ? null : _captureGPSLocation,
              icon: _isCapturingGPS 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.gps_fixed, size: 18),
              label: Text(_isCapturingGPS ? 'Capturing...' : 'Capture GPS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}


/// Data class for team information
class TeamData {
  final int id;
  final String teamName;
  final String memberCount;
  final String role;

  TeamData({
    required this.id,
    required this.teamName,
    required this.memberCount,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'teamName': teamName,
    'memberCount': memberCount,
    'role': role,
  };

  factory TeamData.fromJson(Map<String, dynamic> json) => TeamData(
    id: json['id'] as int,
    teamName: json['teamName'] as String? ?? '',
    memberCount: json['memberCount'] as String? ?? '',
    role: json['role'] as String? ?? '',
  );
}
