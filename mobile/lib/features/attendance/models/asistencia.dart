class Asistencia {
  const Asistencia({
    this.idAsistencia,
    required this.fechaHora,
    required this.latitud,
    required this.longitud,
    this.foto,
    this.observacion,
    required this.estado,
    required this.idEmpleado,
    required this.idTurno,
    required this.idDispositivo,
  });

  final int? idAsistencia;
  final String fechaHora;
  final String latitud;
  final String longitud;
  final String? foto;
  final String? observacion;
  final String estado;
  final int idEmpleado;
  final int idTurno;
  final int idDispositivo;

  factory Asistencia.fromJson(Map<String, dynamic> json) => Asistencia(
    idAsistencia: json['id_asistencia'] as int?,
    fechaHora: json['fecha_hora'] as String,
    latitud: json['latitud'].toString(),
    longitud: json['longitud'].toString(),
    foto: json['foto'] as String?,
    observacion: json['observacion'] as String?,
    estado: json['estado'] as String,
    idEmpleado: json['id_empleado'] as int,
    idTurno: json['id_turno'] as int,
    idDispositivo: json['id_dispositivo'] as int,
  );

  Map<String, dynamic> toJson() => {
    'fecha_hora': fechaHora,
    'latitud': num.tryParse(latitud) ?? latitud,
    'longitud': num.tryParse(longitud) ?? longitud,
    'foto': foto,
    'observacion': observacion,
    'estado': estado,
    'id_empleado': idEmpleado,
    'id_turno': idTurno,
    'id_dispositivo': idDispositivo,
  };
}
