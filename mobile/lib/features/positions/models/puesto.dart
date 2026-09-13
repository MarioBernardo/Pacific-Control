class Puesto {
  const Puesto({
    this.idPuesto,
    required this.nombrePuesto,
    required this.direccion,
    required this.estado,
  });

  final int? idPuesto;
  final String nombrePuesto;
  final String direccion;
  final String estado;

  factory Puesto.fromJson(Map<String, dynamic> json) {
    return Puesto(
      idPuesto: json['id_puesto'] as int?,
      nombrePuesto: json['nombre_puesto'] as String,
      direccion: json['direccion'] as String,
      estado: json['estado'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre_puesto': nombrePuesto,
        'direccion': direccion,
        'estado': estado,
      };

  Puesto copyWith({
    int? idPuesto,
    String? nombrePuesto,
    String? direccion,
    String? estado,
  }) {
    return Puesto(
      idPuesto: idPuesto ?? this.idPuesto,
      nombrePuesto: nombrePuesto ?? this.nombrePuesto,
      direccion: direccion ?? this.direccion,
      estado: estado ?? this.estado,
    );
  }
}
