class UserDto {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final int roleValue;
  final String? phoneNumber;
  final bool isActive;
  final String createdAt;
  final String? lastLoginAt;

  const UserDto({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.roleValue,
    this.phoneNumber,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        role: json['role'] as String,
        roleValue: json['roleValue'] as int,
        phoneNumber: json['phoneNumber'] as String?,
        isActive: json['isActive'] as bool,
        createdAt: json['createdAt'] as String,
        lastLoginAt: json['lastLoginAt'] as String?,
      );
}
