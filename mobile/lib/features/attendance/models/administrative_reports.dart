class PersonnelOnShift {
  const PersonnelOnShift({
    required this.employeeId,
    required this.guard,
    required this.position,
    required this.shiftType,
    required this.startedAt,
    required this.endsAt,
    required this.status,
  });

  final int employeeId;
  final String guard;
  final String position;
  final String shiftType;
  final String startedAt;
  final String endsAt;
  final String status;

  factory PersonnelOnShift.fromJson(Map<String, dynamic> json) =>
      PersonnelOnShift(
        employeeId: json['id_empleado'] as int,
        guard: json['guardia'] as String,
        position: json['puesto'] as String,
        shiftType: json['tipo_turno'] as String,
        startedAt: json['fecha_hora'] as String,
        endsAt: json['finalizacion_estimada'] as String,
        status: json['estado'] as String,
      );
}

class AdministrativeDashboard {
  const AdministrativeDashboard({
    required this.guardsOnShift,
    required this.attendancesToday,
    required this.openIncidents,
    required this.staffedPositions,
    required this.personnel,
  });

  final int guardsOnShift;
  final int attendancesToday;
  final int openIncidents;
  final int staffedPositions;
  final List<PersonnelOnShift> personnel;

  factory AdministrativeDashboard.fromJson(Map<String, dynamic> json) =>
      AdministrativeDashboard(
        guardsOnShift: json['guardias_en_turno'] as int,
        attendancesToday: json['asistencias_hoy'] as int,
        openIncidents: json['novedades_abiertas'] as int,
        staffedPositions: json['puestos_con_personal'] as int,
        personnel: (json['personal_en_turno'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(PersonnelOnShift.fromJson)
            .toList(),
      );
}

class GuardMonthlySummary {
  const GuardMonthlySummary({
    required this.employeeId,
    this.guard,
    required this.month,
    required this.year,
    required this.totalShifts,
    required this.twelveHourShifts,
    required this.twentyFourHourShifts,
    required this.derivedHours,
    required this.attendances,
    required this.positions,
    required this.incidents,
    required this.history,
  });

  final int employeeId;
  final String? guard;
  final int month;
  final int year;
  final int totalShifts;
  final int twelveHourShifts;
  final int twentyFourHourShifts;
  final int derivedHours;
  final int attendances;
  final List<String> positions;
  final int incidents;
  final List<Map<String, dynamic>> history;

  factory GuardMonthlySummary.fromJson(Map<String, dynamic> json) =>
      GuardMonthlySummary(
        employeeId: json['id_empleado'] as int,
        guard: json['guardia'] as String?,
        month: json['mes'] as int,
        year: json['anio'] as int,
        totalShifts: json['total_turnos'] as int,
        twelveHourShifts: json['turnos_12_horas'] as int,
        twentyFourHourShifts: json['turnos_24_horas'] as int,
        derivedHours: json['horas_derivadas'] as int,
        attendances: json['asistencias'] as int,
        positions: (json['puestos'] as List<dynamic>).cast<String>(),
        incidents: json['novedades'] as int,
        history: (json['historial'] as List<dynamic>)
            .cast<Map<String, dynamic>>(),
      );
}
