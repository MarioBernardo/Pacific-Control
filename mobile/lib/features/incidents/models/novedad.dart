class Novedad {
  const Novedad({
    this.idNovedad,
    required this.tipo,
    required this.descripcion,
    required this.fechaHora,
    required this.estado,
    required this.idEmpleado,
    required this.idTurno,
    this.idDispositivo,
    this.evidenciaFoto,
    this.guardiaNombre,
    this.puestoNombre,
    this.tipoTurno,
    this.tipoAsignacion,
    this.dispositivoCodigo,
  });

  final int? idNovedad;
  final String tipo;
  final String descripcion;
  final String fechaHora;
  final String estado;
  final int idEmpleado;
  final int idTurno;
  final int? idDispositivo;
  final String? evidenciaFoto;
  final String? guardiaNombre;
  final String? puestoNombre;
  final String? tipoTurno;
  final String? tipoAsignacion;
  final String? dispositivoCodigo;

  String get fechaHoraLegible {
    final date = DateTime.tryParse(fechaHora)?.toLocal();
    if (date == null) return fechaHora;
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
  }

  factory Novedad.fromJson(Map<String, dynamic> json) => Novedad(
    idNovedad: json['id_novedad'] as int?,
    tipo: json['tipo'] as String,
    descripcion: json['descripcion'] as String,
    fechaHora: json['fecha_hora'] as String,
    estado: json['estado'] as String,
    idEmpleado: json['id_empleado'] as int,
    idTurno: json['id_turno'] as int,
    idDispositivo: json['id_dispositivo'] as int?,
    evidenciaFoto: json['evidencia_foto'] as String?,
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
    'tipo': tipo,
    'descripcion': descripcion,
    'fecha_hora': fechaHora,
    'estado': estado,
    'id_empleado': idEmpleado,
    'id_turno': idTurno,
  };
}
