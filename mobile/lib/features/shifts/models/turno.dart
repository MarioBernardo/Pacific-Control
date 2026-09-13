class Turno {
  const Turno({
    this.idTurno,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.estado,
    required this.idEmpleado,
    required this.idPuesto,
  });

  final int? idTurno;
  final String fecha;
  final String horaInicio;
  final String horaFin;
  final String estado;
  final int idEmpleado;
  final int idPuesto;

  factory Turno.fromJson(Map<String, dynamic> json) {
    return Turno(
      idTurno: json['id_turno'] as int?,
      fecha: json['fecha'] as String,
      horaInicio: json['hora_inicio'] as String,
      horaFin: json['hora_fin'] as String,
      estado: json['estado'] as String,
      idEmpleado: json['id_empleado'] as int,
      idPuesto: json['id_puesto'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'fecha': fecha,
    'hora_inicio': horaInicio,
    'hora_fin': horaFin,
    'estado': estado,
    'id_empleado': idEmpleado,
    'id_puesto': idPuesto,
  };
}
