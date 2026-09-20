class Turno {
  const Turno({
    this.idTurno,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.estado,
    this.tipoTurno = '24 HORAS',
    this.tipoAsignacion = 'FIJO',
    required this.idEmpleado,
    required this.idPuesto,
    this.empleadoNombre,
    this.puestoNombre,
  });

  final int? idTurno;
  final String fecha;
  final String horaInicio;
  final String horaFin;
  final String estado;
  final String tipoTurno;
  final String tipoAsignacion;
  final int idEmpleado;
  final int idPuesto;
  final String? empleadoNombre;
  final String? puestoNombre;

  factory Turno.fromJson(Map<String, dynamic> json) {
    return Turno(
      idTurno: json['id_turno'] as int?,
      fecha: json['fecha'] as String,
      horaInicio: json['hora_inicio'] as String,
      horaFin: json['hora_fin'] as String,
      estado: json['estado'] as String,
      tipoTurno: json['tipo_turno'] as String? ?? '24 HORAS',
      tipoAsignacion: json['tipo_asignacion'] as String? ?? 'FIJO',
      idEmpleado: json['id_empleado'] as int,
      idPuesto: json['id_puesto'] as int,
      empleadoNombre:
          (json['empleado'] as Map<String, dynamic>?)?['nombre_completo']
              as String?,
      puestoNombre:
          (json['puesto'] as Map<String, dynamic>?)?['nombre_puesto']
              as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'fecha': fecha,
    'hora_inicio': horaInicio,
    'hora_fin': horaFin,
    'estado': estado,
    'tipo_turno': tipoTurno,
    'tipo_asignacion': tipoAsignacion,
    'id_empleado': idEmpleado,
    'id_puesto': idPuesto,
  };
}
