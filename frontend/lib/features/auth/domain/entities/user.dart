import 'package:equatable/equatable.dart';

/// User entity (pure Dart, no Flutter dependencies)
class User extends Equatable {
  final String id;
  final String email;
  final String name;
  final String role;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  @override
  List<Object?> get props => [id, email, name, role];
}
