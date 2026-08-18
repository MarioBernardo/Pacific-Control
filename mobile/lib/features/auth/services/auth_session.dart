class AuthSession {
  const AuthSession({required this.accessToken, required this.employee});

  final String accessToken;
  final AuthEmployee employee;

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'empleado': employee.toJson(),
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final employeeJson = json['empleado'];
    if (json['access_token'] is! String || employeeJson is! Map<String, dynamic>) {
      throw const FormatException('Sesión inválida.');
    }
    return AuthSession(
      accessToken: json['access_token'] as String,
      employee: AuthEmployee.fromJson(employeeJson),
    );
  }
}

class AuthEmployee {
  const AuthEmployee({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.position,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String position;

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombres': firstName,
        'apellidos': lastName,
        'correo': email,
        'cargo': position,
      };

  factory AuthEmployee.fromJson(Map<String, dynamic> json) {
    return AuthEmployee(
      id: json['id'] as int,
      firstName: json['nombres'] as String,
      lastName: json['apellidos'] as String,
      email: json['correo'] as String,
      position: json['cargo'] as String,
    );
  }
}
