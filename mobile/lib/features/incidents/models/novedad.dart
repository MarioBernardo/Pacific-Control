class Novedad {
  const Novedad({
    this.idNovedad,
    required this.tipo,
    required this.descripcion,
    required this.fechaHora,
    required this.estado,
    required this.idEmpleado,
    required this.idTurno,
  });

  final int? idNovedad;
  final String tipo;
  final String descripcion;
  final String fechaHora;
  final String estado;
  final int idEmpleado;
  final int idTurno;

  factory Novedad.fromJson(Map<String, dynamic> json) => Novedad(
    idNovedad: json['id_novedad'] as int?,
    tipo: json['tipo'] as String,
    descripcion: json['descripcion'] as String,
    fechaHora: json['fecha_hora'] as String,
    estado: json['estado'] as String,
    idEmpleado: json['id_empleado'] as int,
    idTurno: json['id_turno'] as int,
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
