class Empleado {
  const Empleado({
    required this.idEmpleado,
    required this.cedula,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    required this.telefono,
    required this.cargo,
    required this.estado,
  });

  final int idEmpleado;
  final String cedula;
  final String nombres;
  final String apellidos;
  final String correo;
  final String telefono;
  final String cargo;
  final bool estado;

  factory Empleado.fromJson(Map<String, dynamic> json) => Empleado(
        idEmpleado: json['id_empleado'] as int,
        cedula: json['cedula'] as String,
        nombres: json['nombres'] as String,
        apellidos: json['apellidos'] as String,
        correo: json['correo'] as String,
        telefono: json['telefono'] as String,
        cargo: json['cargo'] as String,
        estado: json['estado'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'cedula': cedula,
        'nombres': nombres,
        'apellidos': apellidos,
        'correo': correo,
        'telefono': telefono,
        'cargo': cargo,
        'estado': estado,
      };
}
