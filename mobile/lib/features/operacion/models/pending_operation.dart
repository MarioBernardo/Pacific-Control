enum PendingOperationType { asistencia, novedad }

enum PendingOperationStatus { pendiente, enviando, sincronizado, error }

extension PendingOperationStatusValue on PendingOperationStatus {
  String get value => switch (this) {
    PendingOperationStatus.pendiente => 'PENDIENTE',
    PendingOperationStatus.enviando => 'ENVIANDO',
    PendingOperationStatus.sincronizado => 'SINCRONIZADO',
    PendingOperationStatus.error => 'ERROR',
  };
}

class PendingOperation {
  const PendingOperation({
    required this.operationId,
    required this.type,
    required this.deviceId,
    required this.payload,
    required this.localDate,
    required this.status,
    required this.attempts,
    this.lastError,
    this.photoPath,
  });

  final String operationId;
  final PendingOperationType type;
  final int deviceId;
  final Map<String, dynamic> payload;
  final DateTime localDate;
  final PendingOperationStatus status;
  final int attempts;
  final String? lastError;
  final String? photoPath;

  bool get needsSync => status != PendingOperationStatus.sincronizado;

  PendingOperation copyWith({
    PendingOperationStatus? status,
    int? attempts,
    String? lastError,
    bool clearLastError = false,
    String? photoPath,
  }) {
    return PendingOperation(
      operationId: operationId,
      type: type,
      deviceId: deviceId,
      payload: payload,
      localDate: localDate,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'operation_id': operationId,
    'tipo': type.name.toUpperCase(),
    'device_id': deviceId,
    'payload': payload,
    'fecha_local': localDate.toIso8601String(),
    'estado': status.value,
    'intentos': attempts,
    'ultimo_error': lastError,
    'foto_local': photoPath,
  };

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      operationId: json['operation_id'] as String,
      type: PendingOperationType.values.byName(
        (json['tipo'] as String).toLowerCase(),
      ),
      deviceId: json['device_id'] as int,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      localDate: DateTime.parse(json['fecha_local'] as String),
      status: PendingOperationStatus.values.firstWhere(
        (value) => value.value == json['estado'],
      ),
      attempts: json['intentos'] as int,
      lastError: json['ultimo_error'] as String?,
      photoPath: json['foto_local'] as String?,
    );
  }
}
