class Dispositivo {
  const Dispositivo({
    this.idDispositivo,
    required this.codigoDispositivo,
    required this.modelo,
    required this.estado,
    required this.idPuesto,
    this.puestoNombre,
  });

  final int? idDispositivo;
  final String codigoDispositivo;
  final String? modelo;
  final String estado;
  final int idPuesto;
  final String? puestoNombre;

  factory Dispositivo.fromJson(Map<String, dynamic> json) {
    return Dispositivo(
      idDispositivo: json['id_dispositivo'] as int?,
      codigoDispositivo: json['codigo_dispositivo'] as String,
      modelo: json['modelo'] as String?,
      estado: json['estado'] as String,
      idPuesto: json['id_puesto'] as int,
      puestoNombre:
          (json['puesto'] as Map<String, dynamic>?)?['nombre_puesto']
              as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'codigo_dispositivo': codigoDispositivo,
    'modelo': modelo,
    'estado': estado,
    'id_puesto': idPuesto,
  };
}
