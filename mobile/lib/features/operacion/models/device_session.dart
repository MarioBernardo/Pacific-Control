// Models for the operative device session flow.
library;

class DispositivoInfo {
  const DispositivoInfo({
    required this.idDispositivo,
    required this.codigoDispositivo,
    this.modelo,
    required this.estado,
    required this.idPuesto,
    this.puesto,
  });

  final int idDispositivo;
  final String codigoDispositivo;
  final String? modelo;
  final String estado;
  final int idPuesto;
  final PuestoInfo? puesto;

  factory DispositivoInfo.fromJson(Map<String, dynamic> json) {
    return DispositivoInfo(
      idDispositivo: json['id_dispositivo'] as int,
      codigoDispositivo: json['codigo_dispositivo'] as String,
      modelo: json['modelo'] as String?,
      estado: json['estado'] as String,
      idPuesto: json['id_puesto'] as int,
      puesto: json['puesto'] != null
          ? PuestoInfo.fromJson(json['puesto'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PuestoInfo {
  const PuestoInfo({
    required this.idPuesto,
    required this.nombrePuesto,
    required this.direccion,
    required this.estado,
  });

  final int idPuesto;
  final String nombrePuesto;
  final String direccion;
  final String estado;

  factory PuestoInfo.fromJson(Map<String, dynamic> json) {
    return PuestoInfo(
      idPuesto: json['id_puesto'] as int,
      nombrePuesto: json['nombre_puesto'] as String,
      direccion: json['direccion'] as String,
      estado: json['estado'] as String,
    );
  }
}

class GuardiaDisponible {
  const GuardiaDisponible({
    required this.idEmpleado,
    required this.nombres,
    required this.apellidos,
    required this.nombreCompleto,
    required this.cargo,
    required this.tipoAsignacion,
    required this.turnosDisponibles,
    required this.idPuesto,
  });

  final int idEmpleado;
  final String nombres;
  final String apellidos;
  final String nombreCompleto;
  final String cargo;
  final String tipoAsignacion;
  final List<TurnoDisponible> turnosDisponibles;
  final int idPuesto;

  bool get esFijo => tipoAsignacion.toUpperCase() == 'FIJO';

  factory GuardiaDisponible.fromJson(Map<String, dynamic> json) {
    return GuardiaDisponible(
      idEmpleado: json['id_empleado'] as int,
      nombres: json['nombres'] as String,
      apellidos: json['apellidos'] as String,
      nombreCompleto: json['nombre_completo'] as String,
      cargo: json['cargo'] as String,
      tipoAsignacion: json['tipo_asignacion'] as String,
      turnosDisponibles: (json['turnos_disponibles'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(TurnoDisponible.fromJson)
          .toList(),
      idPuesto: json['id_puesto'] as int,
    );
  }
}

class TurnoDisponible {
  const TurnoDisponible({required this.idTurno, required this.tipoTurno});

  final int idTurno;
  final String tipoTurno;

  factory TurnoDisponible.fromJson(Map<String, dynamic> json) {
    return TurnoDisponible(
      idTurno: json['id_turno'] as int,
      tipoTurno: json['tipo_turno'] as String,
    );
  }
}

class GuardiaIdentificado {
  const GuardiaIdentificado({
    required this.idEmpleado,
    required this.nombres,
    required this.apellidos,
    required this.nombreCompleto,
    required this.cargo,
    required this.tipoAsignacion,
    this.tipoTurno,
    this.idTurno,
  });

  final int idEmpleado;
  final String nombres;
  final String apellidos;
  final String nombreCompleto;
  final String cargo;
  final String tipoAsignacion;
  final String? tipoTurno;
  final int? idTurno;

  bool get esFijo => tipoAsignacion.toUpperCase() == 'FIJO';

  factory GuardiaIdentificado.fromJson(Map<String, dynamic> json) {
    return GuardiaIdentificado(
      idEmpleado: json['id_empleado'] as int,
      nombres: json['nombres'] as String,
      apellidos: json['apellidos'] as String,
      nombreCompleto: json['nombre_completo'] as String,
      cargo: json['cargo'] as String,
      tipoAsignacion: json['tipo_asignacion'] as String,
      tipoTurno: json['tipo_turno'] as String?,
      idTurno: json['id_turno'] as int?,
    );
  }
}

class SesionOperativa {
  const SesionOperativa({
    required this.dispositivo,
    this.guardiaIdentificado,
    required this.estado,
  });

  final DispositivoInfo dispositivo;
  final GuardiaIdentificado? guardiaIdentificado;
  final String estado;

  bool get identificado =>
      estado == 'identificado' && guardiaIdentificado != null;

  factory SesionOperativa.fromJson(Map<String, dynamic> json) {
    return SesionOperativa(
      dispositivo: DispositivoInfo.fromJson(
        json['dispositivo'] as Map<String, dynamic>,
      ),
      guardiaIdentificado: json['guardia_identificado'] != null
          ? GuardiaIdentificado.fromJson(
              json['guardia_identificado'] as Map<String, dynamic>,
            )
          : null,
      estado: json['estado'] as String,
    );
  }
}
