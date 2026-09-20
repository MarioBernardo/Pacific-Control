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
    this.guardiaNombre,
    this.puestoNombre,
    this.tipoTurno,
    this.tipoAsignacion,
    this.dispositivoCodigo,
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
  final String? guardiaNombre;
  final String? puestoNombre;
  final String? tipoTurno;
  final String? tipoAsignacion;
  final String? dispositivoCodigo;

  String get fechaHoraLegible => _formatDateTime(fechaHora);

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
    guardiaNombre:
        (json['guardia'] as Map<String, dynamic>?)?['nombre_completo']
            as String?,
    puestoNombre:
        (json['puesto'] as Map<String, dynamic>?)?['nombre_puesto'] as String?,
    tipoTurno:
        (json['turno'] as Map<String, dynamic>?)?['tipo_turno'] as String?,
    tipoAsignacion:
        (json['turno'] as Map<String, dynamic>?)?['tipo_asignacion'] as String?,
    dispositivoCodigo:
        (json['dispositivo'] as Map<String, dynamic>?)?['codigo_dispositivo']
            as String?,
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

String _formatDateTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
}
